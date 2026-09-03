import Foundation

extension AppViewModel {
    // MARK: - Price Index Helpers

    /// Builds an ascending-sorted price index for each ISIN, loading all data from DB once.
    private func buildPriceIndex(for isins: [String]) async -> [String: [(date: String, value: Double)]] {
        var index: [String: [(date: String, value: Double)]] = [:]
        index.reserveCapacity(isins.count)
        for isin in isins {
            let history = await db.getPriceHistory(forIsin: isin)
            index[isin] = history.map { ($0.date, $0.value) }.reversed()
        }
        return index
    }

    private func transactionsByIsin(_ transactions: [HoldingTransaction]) -> [String: [(date: String, quantityDelta: Double)]] {
        var result: [String: [(date: String, quantityDelta: Double)]] = [:]
        for tx in transactions {
            result[tx.isin, default: []].append((tx.date, tx.quantityDelta))
        }
        return result
    }

    private func aggregatedValueHistory(
        isins: [String],
        fallbackQuantityByIsin: [String: Double],
        transactions: [HoldingTransaction],
        cutoffStr: String
    ) async -> [(date: Date, value: Double)] {
        if isins.isEmpty { return [] }

        let priceIndex = await buildPriceIndex(for: isins)
        let todayStr = AppDateFormatter.todayString
        let txByIsin = transactionsByIsin(transactions)
        let dates = PortfolioHistoryBuilder.chartDates(
            cutoff: cutoffStr,
            today: todayStr,
            priceDates: isins.map { priceIndex[$0]?.map(\.date) ?? [] },
            transactionDates: transactions.map(\.date)
        )
        let holdings = isins.map { (isin: $0, quantity: fallbackQuantityByIsin[$0] ?? 0) }

        let points = await PortfolioHistoryBuilder.series(
            dates: dates,
            holdings: holdings,
            prices: priceIndex,
            transactionsByIsin: txByIsin
        ) { isin, nativeValue, dateStr in
            await convertToEUR(
                value: nativeValue,
                fromCurrency: getInstrumentCurrency(forIsin: isin),
                onDate: dateStr
            )
        }

        return points.compactMap { point in
            guard let date = AppDateFormatter.yearMonthDay.date(from: point.date) else { return nil }
            return (date: date, value: point.value)
        }
    }

    private func historyUniverse(
        instrumentFilter: ((Instrument) -> Bool)? = nil,
        accountId: Int? = nil
    ) async -> (isins: [String], fallback: [String: Double], transactions: [HoldingTransaction]) {
        let allTx = await db.getAllHoldingTransactions()
        let txs = accountId.map { id in allTx.filter { $0.accountId == id } } ?? allTx

        var isins = Set<String>()
        var fallback: [String: Double] = [:]

        let relevantHoldings: [Holding]
        if let accountId {
            relevantHoldings = holdings.filter { $0.accountId == accountId }
        } else {
            relevantHoldings = holdings
        }
        for holding in relevantHoldings where holding.quantity > 0 {
            if let filter = instrumentFilter {
                guard let instrument = instruments.first(where: { $0.isin == holding.isin }), filter(instrument) else { continue }
            }
            isins.insert(holding.isin)
            fallback[holding.isin, default: 0] += holding.quantity
        }
        for tx in txs {
            if let filter = instrumentFilter {
                guard let instrument = instruments.first(where: { $0.isin == tx.isin }), filter(instrument) else { continue }
            }
            isins.insert(tx.isin)
            if fallback[tx.isin] == nil {
                fallback[tx.isin] = 0
            }
        }
        return (Array(isins), fallback, txs)
    }

    func periodTWR(from history: [(date: Date, value: Double)]) async -> Double? {
        guard !history.isEmpty else { return nil }
        let cutoffStr = AppDateFormatter.yearMonthDay.string(from: selectedPeriod.comparisonDate)
        let todayStr = AppDateFormatter.todayString
        let txs = await db.getAllHoldingTransactions()
        let intra = txs.filter { $0.date > cutoffStr && $0.date <= todayStr }
        let isins = Array(Set(intra.map(\.isin)))
        let priceIndex = await buildPriceIndex(for: isins)

        var cfByDate: [String: Double] = [:]
        for tx in intra {
            let price = PortfolioHistoryBuilder.priceOnOrBeforeOrFirst(
                index: priceIndex[tx.isin] ?? [],
                date: tx.date
            )
            guard let price, price > 0 else { continue }
            let native = tx.quantityDelta * price
            if let eur = await convertToEUR(
                value: native,
                fromCurrency: getInstrumentCurrency(forIsin: tx.isin),
                onDate: tx.date
            ) {
                cfByDate[tx.date, default: 0] += eur
            }
        }
        let nav = history.map { (AppDateFormatter.yearMonthDay.string(from: $0.date), $0.value) }
        let cashflows = cfByDate.map { (date: $0.key, amountEUR: $0.value) }
        return PortfolioHistoryBuilder.timeWeightedReturn(nav: nav, cashflows: cashflows)
    }

    // MARK: - Portfolio History
    func getPortfolioValueHistory() async -> [(date: Date, value: Double)] {
        clearRateCache()
        let cutoffStr = AppDateFormatter.yearMonthDay.string(from: selectedPeriod.comparisonDate)
        let universe = await historyUniverse()
        return await aggregatedValueHistory(
            isins: universe.isins,
            fallbackQuantityByIsin: universe.fallback,
            transactions: universe.transactions,
            cutoffStr: cutoffStr
        )
    }

    /// Get portfolio value history in gold ounces (converts EUR history using gold prices at each date)
    func getGoldOzHistory() async -> [(date: Date, value: Double)] {
        let eurHistory = await getPortfolioValueHistory()
        if eurHistory.isEmpty { return [] }

        let goldIndex = (await buildPriceIndex(for: ["VERACASH:GOLD_SPOT"]))["VERACASH:GOLD_SPOT"] ?? []

        var goldHistory: [(date: Date, value: Double)] = []
        goldHistory.reserveCapacity(eurHistory.count)
        for point in eurHistory {
            let dateStr = AppDateFormatter.yearMonthDay.string(from: point.date)
            if let gramPrice = PortfolioHistoryBuilder.priceOnOrBeforeOrFirst(index: goldIndex, date: dateStr), gramPrice > 0 {
                let goldOuncePrice = gramPrice * 31.1034768
                let goldOz = point.value / goldOuncePrice
                goldHistory.append((date: point.date, value: goldOz))
            }
        }
        return goldHistory
    }

    /// Benchmark comparison helper: scales initial portfolio value by benchmark performance.
    private func benchmarkComparisonHistory(benchmarkIsin: String) async -> [(date: Date, value: Double)] {
        let portfolioHistory = await getPortfolioValueHistory()
        guard let first = portfolioHistory.first, first.value > 0 else { return [] }
        let (date0, value0) = (first.date, first.value)
        let date0Str = AppDateFormatter.yearMonthDay.string(from: date0)

        let benchIndex = (await buildPriceIndex(for: [benchmarkIsin]))[benchmarkIsin] ?? []
        guard let benchAtStart = PortfolioHistoryBuilder.priceOnOrBeforeOrFirst(index: benchIndex, date: date0Str), benchAtStart > 0 else { return [] }

        var result: [(date: Date, value: Double)] = []
        result.reserveCapacity(portfolioHistory.count)
        for point in portfolioHistory {
            let dateStr = AppDateFormatter.yearMonthDay.string(from: point.date)
            guard let benchValue = PortfolioHistoryBuilder.priceOnOrBeforeOrFirst(index: benchIndex, date: dateStr), benchValue > 0 else { continue }
            let scaled = value0 * (benchValue / benchAtStart)
            result.append((date: point.date, value: scaled))
        }
        return result
    }

    /// S&P 500 comparison: same-date series as portfolio history, values = initial portfolio value scaled by S&P performance.
    func getSP500ComparisonHistory() async -> [(date: Date, value: Double)] {
        await benchmarkComparisonHistory(benchmarkIsin: SP500IndexIsin)
    }

    /// Gold comparison: same-date series as portfolio history, values = initial portfolio value scaled by Gold performance.
    func getGoldComparisonHistory() async -> [(date: Date, value: Double)] {
        await benchmarkComparisonHistory(benchmarkIsin: GoldIndexIsin)
    }

    /// MSCI World comparison: same-date series as portfolio history, values = initial portfolio value scaled by MSCI World performance.
    func getMSCIWorldComparisonHistory() async -> [(date: Date, value: Double)] {
        await benchmarkComparisonHistory(benchmarkIsin: MSCIWorldIndexIsin)
    }

    func getQuadrantValueHistory(quadrantId: Int?) async -> [(date: Date, value: Double)] {
        clearRateCache()
        let cutoffStr = AppDateFormatter.yearMonthDay.string(from: selectedPeriod.comparisonDate)
        let universe = await historyUniverse(instrumentFilter: { $0.quadrantId == quadrantId })
        return await aggregatedValueHistory(
            isins: universe.isins,
            fallbackQuantityByIsin: universe.fallback,
            transactions: universe.transactions,
            cutoffStr: cutoffStr
        )
    }

    /// Convert quadrant value history from EUR to gold ounces using Veracash gold spot price
    func getQuadrantValueHistoryInGold(quadrantId: Int?) async -> [(date: Date, value: Double)] {
        let eurHistory = await getQuadrantValueHistory(quadrantId: quadrantId)
        if eurHistory.isEmpty { return [] }

        let goldIndex = (await buildPriceIndex(for: ["VERACASH:GOLD_SPOT"]))["VERACASH:GOLD_SPOT"] ?? []
        if goldIndex.isEmpty { return [] }

        var goldPricesByDate: [String: Double] = [:]
        goldPricesByDate.reserveCapacity(goldIndex.count)
        for entry in goldIndex {
            goldPricesByDate[entry.date] = entry.value * 31.1034768
        }

        var goldHistory: [(date: Date, value: Double)] = []
        goldHistory.reserveCapacity(eurHistory.count)
        var lastKnownGoldPrice: Double? = nil

        for point in eurHistory {
            let dateStr = AppDateFormatter.yearMonthDay.string(from: point.date)

            let goldOuncePrice: Double
            if let price = goldPricesByDate[dateStr] {
                goldOuncePrice = price
                lastKnownGoldPrice = price
            } else if let lastPrice = lastKnownGoldPrice {
                goldOuncePrice = lastPrice
            } else if let gramPrice = PortfolioHistoryBuilder.priceOnOrBeforeOrFirst(index: goldIndex, date: dateStr), gramPrice > 0 {
                let ouncePrice = gramPrice * 31.1034768
                goldOuncePrice = ouncePrice
                lastKnownGoldPrice = ouncePrice
            } else {
                continue
            }

            if goldOuncePrice > 0 {
                let goldOunces = point.value / goldOuncePrice
                goldHistory.append((date: point.date, value: goldOunces))
            }
        }

        return goldHistory
    }

    func getHoldingValueHistory(isin: String, quantity: Double) async -> [(date: Date, value: Double)] {
        clearRateCache()
        let cutoffStr = AppDateFormatter.yearMonthDay.string(from: selectedPeriod.comparisonDate)
        let txs = await db.getHoldingTransactions(forIsin: isin)
        let dbQty = await db.getTotalQuantity(forIsin: isin)
        let fallback = dbQty > 0 ? dbQty : quantity
        return await aggregatedValueHistory(
            isins: [isin],
            fallbackQuantityByIsin: [isin: fallback],
            transactions: txs,
            cutoffStr: cutoffStr
        )
    }

    func getAccountValueHistory(accountId: Int) async -> [(date: Date, value: Double)] {
        clearRateCache()
        let cutoffStr = AppDateFormatter.yearMonthDay.string(from: selectedPeriod.comparisonDate)
        let universe = await historyUniverse(accountId: accountId)
        return await aggregatedValueHistory(
            isins: universe.isins,
            fallbackQuantityByIsin: universe.fallback,
            transactions: universe.transactions,
            cutoffStr: cutoffStr
        )
    }
}
