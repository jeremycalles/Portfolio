import Foundation

extension AppViewModel {
    // MARK: - Price Index Helpers

    /// Builds an ascending-sorted price index for each ISIN, loading all data from DB once.
    private func buildPriceIndex(for isins: [String]) async -> [String: [(date: String, value: Double)]] {
        let unique = Array(Set(isins))
        let prices = await pricesInInstrumentCurrency(await db.getPriceHistory(forIsins: unique))
        var index = Dictionary(uniqueKeysWithValues: unique.map { ($0, [(date: String, value: Double)]()) })
        for price in prices {
            index[price.isin, default: []].append((price.date, price.value))
        }
        return index
    }

    func cashflowData(
        transactions: [HoldingTransaction]
    ) async -> (cashflows: [PortfolioCashflow], events: [PortfolioChartEvent], isComplete: Bool) {
        let priceIndex = await buildPriceIndex(for: Array(Set(transactions.map(\.isin))))
        var cashflows: [PortfolioCashflow] = []
        var events: [PortfolioChartEvent] = []
        var isComplete = true
        cashflows.reserveCapacity(transactions.count)
        events.reserveCapacity(transactions.count)

        for transaction in transactions {
            let fallbackPrice = PortfolioHistoryBuilder.priceOnOrBefore(
                index: priceIndex[transaction.isin] ?? [],
                date: transaction.date
            )
            guard let price = transaction.unitPrice ?? fallbackPrice, price.isFinite, price >= 0 else { isComplete = false; continue }
            // A fee increases a contribution and reduces the proceeds of a withdrawal.
            let native = transaction.quantityDelta * price + max(0, transaction.fees ?? 0)
            guard let amountEUR = await convertToEUR(
                value: native,
                fromCurrency: getInstrumentCurrency(forIsin: transaction.isin),
                onDate: transaction.date
            ) else { isComplete = false; continue }
            let cashflow = PortfolioCashflow(date: transaction.date, amountEUR: amountEUR)
            cashflows.append(cashflow)
            events.append(PortfolioChartEvent(transaction: transaction, amountEUR: amountEUR))
        }
        return (cashflows, events, isComplete)
    }

    private func transactionsByIsin(_ transactions: [HoldingTransaction]) -> [String: [(date: String, quantityDelta: Double)]] {
        var result: [String: [(date: String, quantityDelta: Double)]] = [:]
        for tx in transactions {
            result[tx.isin, default: []].append((tx.date, tx.quantityDelta))
        }
        return result
    }

    /// Whether the selected period's return can be computed. Only that period's
    /// transactions need a price, so an unpriced older one must not hide the return.
    /// An all-time return starts at the first transaction, so it needs them all.
    func hasCompletePeriodCashflows(_ transactions: [HoldingTransaction]) async -> Bool {
        guard selectedPeriod != .all else {
            return await cashflowData(transactions: transactions).isComplete
        }
        let cutoff = historyCutoff(for: transactions)
        let today = AppDateFormatter.todayString
        return await cashflowData(
            transactions: transactions.filter { $0.date > cutoff && $0.date <= today }
        ).isComplete
    }

    private func historyCutoff(for transactions: [HoldingTransaction]) -> String {
        if selectedPeriod == .all {
            return transactions.map(\.date).min() ?? AppDateFormatter.todayString
        }
        return AppDateFormatter.yearMonthDay.string(from: selectedPeriod.comparisonDate)
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
            transactionsByIsin: txByIsin,
            today: todayStr
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
        await periodTWR(from: history, transactions: await db.getAllHoldingTransactions())
    }

    private func periodTWR(
        from history: [(date: Date, value: Double)],
        transactions: [HoldingTransaction]
    ) async -> Double? {
        guard !history.isEmpty else { return nil }
        let cutoffStr = historyCutoff(for: transactions)
        let todayStr = AppDateFormatter.todayString
        let intra = transactions.filter { $0.date > cutoffStr && $0.date <= todayStr }
        let data = await cashflowData(transactions: intra)
        guard data.isComplete else { return nil }
        let flows = data.cashflows
        let nav = history.map { (AppDateFormatter.yearMonthDay.string(from: $0.date), $0.value) }
        let cashflows = flows.map { (date: $0.date, amountEUR: $0.amountEUR) }
        return PortfolioHistoryBuilder.timeWeightedReturn(nav: nav, cashflows: cashflows)
    }

    func getHoldingTWR(isin: String, history: [(date: Date, value: Double)]) async -> Double? {
        let transactions = await db.getHoldingTransactions(forIsin: isin)
        return await periodTWR(from: history, transactions: transactions)
    }

    func getAccountTWR(accountId: Int, history: [(date: Date, value: Double)]) async -> Double? {
        let transactions = await db.getAllHoldingTransactions().filter { $0.accountId == accountId }
        return await periodTWR(from: history, transactions: transactions)
    }

    func getQuadrantTWR(quadrantId: Int?, history: [(date: Date, value: Double)]) async -> Double? {
        await periodTWR(from: history, transactions: await getQuadrantTransactions(quadrantId: quadrantId))
    }

    func getQuadrantTransactions(quadrantId: Int?) async -> [HoldingTransaction] {
        let matchingISINs = Set(instruments.filter { $0.quadrantId == quadrantId }.map(\.isin))
        return await db.getAllHoldingTransactions().filter { matchingISINs.contains($0.isin) }
    }

    /// Time-weighted return of a quadrant over the selected period, with its own
    /// cashflows. Empty when a transaction of the period has no price.
    func getQuadrantReturnSeries(quadrantId: Int?) async -> [(date: Date, value: Double)] {
        let history = await getQuadrantValueHistory(quadrantId: quadrantId)
        guard !history.isEmpty else { return [] }
        let transactions = await getQuadrantTransactions(quadrantId: quadrantId)
        guard await hasCompletePeriodCashflows(transactions) else { return [] }
        let flows = await cashflowData(transactions: transactions)
        return PortfolioAnalytics.returnSeries(history, cashflows: flows.cashflows)
    }

    /// Computes all top-level chart series from one portfolio history and one set of
    /// transaction cashflows. The resulting value can be published atomically.
    func makeDashboardSnapshot() async -> DashboardSnapshot {
        clearRateCache()
        let portfolio = await getPortfolioValueHistory()
        guard !portfolio.isEmpty else { return DashboardSnapshot() }

        let transactions = await db.getAllHoldingTransactions()
        let flowData = await cashflowData(transactions: transactions)
        let cutoff = historyCutoff(for: transactions)
        let today = AppDateFormatter.todayString
        let periodFlows = flowData.cashflows.filter { $0.date > cutoff && $0.date <= today }
        let hasCompleteReturns = await hasCompletePeriodCashflows(transactions)
        let benchmarkIDs = [SP500IndexIsin, GoldIndexIsin, MSCIWorldIndexIsin, "VERACASH:GOLD_SPOT"]
        let indices = await buildPriceIndex(for: benchmarkIDs)
        let derived = await PortfolioAnalytics.deriveDashboardSeries(
            portfolio: portfolio,
            allCashflows: flowData.cashflows,
            periodCashflows: periodFlows,
            sp500Index: indices[SP500IndexIsin] ?? [],
            goldIndex: indices[GoldIndexIsin] ?? [],
            msciWorldIndex: indices[MSCIWorldIndexIsin] ?? []
        )
        let goldOunces = portfolio.compactMap { point -> (date: Date, value: Double)? in
            let date = AppDateFormatter.yearMonthDay.string(from: point.date)
            guard let gramPrice = PortfolioHistoryBuilder.priceOnOrBefore(
                index: indices["VERACASH:GOLD_SPOT"] ?? [],
                date: date
            ), gramPrice > 0 else { return nil }
            return (point.date, point.value / (gramPrice * 31.1034768))
        }
        let firstDate = AppDateFormatter.yearMonthDay.string(from: portfolio[0].date)
        let netFlowsAfterFirstPoint = flowData.cashflows
            .filter { $0.date > firstDate && $0.date <= today }
            .reduce(0) { $0 + $1.amountEUR }
        let gainEUR = portfolio[portfolio.count - 1].value - portfolio[0].value - netFlowsAfterFirstPoint

        return DashboardSnapshot(
            portfolio: portfolio,
            investedCapital: flowData.isComplete ? derived.investedCapital : [],
            sp500: hasCompleteReturns ? derived.sp500 : [],
            gold: hasCompleteReturns ? derived.gold : [],
            msciWorld: hasCompleteReturns ? derived.msciWorld : [],
            goldOunces: goldOunces,
            events: flowData.events.filter {
                let date = AppDateFormatter.yearMonthDay.string(from: $0.date)
                return date >= cutoff && date <= today
            },
            timeWeightedReturn: hasCompleteReturns ? derived.timeWeightedReturn : nil,
            gainEUR: hasCompleteReturns && gainEUR.isFinite ? gainEUR : nil,
            cashflows: flowData.cashflows,
            hasCompleteCashflows: hasCompleteReturns
        )
    }

    // MARK: - Portfolio History
    func getPortfolioValueHistory() async -> [(date: Date, value: Double)] {
        clearRateCache()
        let universe = await historyUniverse()
        return await aggregatedValueHistory(
            isins: universe.isins,
            fallbackQuantityByIsin: universe.fallback,
            transactions: universe.transactions,
            cutoffStr: historyCutoff(for: universe.transactions)
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
            if let gramPrice = PortfolioHistoryBuilder.priceOnOrBefore(index: goldIndex, date: dateStr), gramPrice > 0 {
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
        let transactions = await db.getAllHoldingTransactions()
        let cutoff = historyCutoff(for: transactions)
        let flows = await cashflowData(transactions: transactions).cashflows.filter { $0.date > cutoff }
        let benchIndex = (await buildPriceIndex(for: [benchmarkIsin]))[benchmarkIsin] ?? []
        return PortfolioAnalytics.benchmarkSeries(
            portfolio: portfolioHistory,
            benchmark: benchIndex,
            cashflows: flows
        )
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
        let universe = await historyUniverse(instrumentFilter: { $0.quadrantId == quadrantId })
        return await aggregatedValueHistory(
            isins: universe.isins,
            fallbackQuantityByIsin: universe.fallback,
            transactions: universe.transactions,
            cutoffStr: historyCutoff(for: universe.transactions)
        )
    }

    /// Convert quadrant value history from EUR to gold ounces using Veracash gold spot price
    func getQuadrantValueHistoryInGold(quadrantId: Int?) async -> [(date: Date, value: Double)] {
        let eurHistory = await getQuadrantValueHistory(quadrantId: quadrantId)
        return await valueHistoryInGold(eurHistory)
    }

    func valueHistoryInGold(_ eurHistory: [(date: Date, value: Double)]) async -> [(date: Date, value: Double)] {
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
            } else if let gramPrice = PortfolioHistoryBuilder.priceOnOrBefore(index: goldIndex, date: dateStr), gramPrice > 0 {
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
        let txs = await db.getHoldingTransactions(forIsin: isin)
        let dbQty = await db.getTotalQuantity(forIsin: isin)
        let fallback = dbQty > 0 ? dbQty : quantity
        return await aggregatedValueHistory(
            isins: [isin],
            fallbackQuantityByIsin: [isin: fallback],
            transactions: txs,
            cutoffStr: historyCutoff(for: txs)
        )
    }

    func getPositionValueHistory(accountId: Int, isin: String) async -> [(date: Date, value: Double)] {
        clearRateCache()
        let transactions = await db.getHoldingTransactions(accountId: accountId, isin: isin)
        let liveQuantity = holdings.first {
            $0.accountId == accountId && $0.isin == isin
        }?.quantity ?? HoldingLedger.quantity(transactions: transactions)
        return await aggregatedValueHistory(
            isins: [isin],
            fallbackQuantityByIsin: [isin: liveQuantity],
            transactions: transactions,
            cutoffStr: historyCutoff(for: transactions)
        )
    }

    func getAccountValueHistory(accountId: Int) async -> [(date: Date, value: Double)] {
        clearRateCache()
        let universe = await historyUniverse(accountId: accountId)
        return await aggregatedValueHistory(
            isins: universe.isins,
            fallbackQuantityByIsin: universe.fallback,
            transactions: universe.transactions,
            cutoffStr: historyCutoff(for: universe.transactions)
        )
    }

    // MARK: - Moving Averages

    /// Moving average of the instrument price divided by the price, at each of `dates`.
    /// The chart multiplies the position line by it, so quantity changes and
    /// currency conversion never distort the average.
    func instrumentMovingAverageRatios(
        isin: String,
        at dates: [Date]
    ) async -> [MovingAverageWindow: [(date: Date, value: Double)]] {
        guard !dates.isEmpty else { return [:] }
        let prices = (await buildPriceIndex(for: [isin]))[isin] ?? []
        let points = prices.compactMap { price -> (date: Date, value: Double)? in
            AppDateFormatter.yearMonthDay.date(from: price.date).map { ($0, price.value) }
        }
        return MovingAverage.ratiosByWindow(points, at: dates)
    }

    /// Same ratio for a quadrant, computed on its time-weighted performance index
    /// over its whole history, so contributions and withdrawals do not move the average.
    func quadrantMovingAverageRatios(
        quadrantId: Int,
        at dates: [Date]
    ) async -> [MovingAverageWindow: [(date: Date, value: Double)]] {
        guard !dates.isEmpty else { return [:] }
        clearRateCache()
        let universe = await historyUniverse(instrumentFilter: { $0.quadrantId == quadrantId })
        let isins = Set(universe.isins)
        let transactions = universe.transactions.filter { isins.contains($0.isin) }
        let priceIndex = await buildPriceIndex(for: universe.isins)
        let earliestPrice = priceIndex.values.compactMap { $0.first?.date }.min()
        guard let start = transactions.map(\.date).min() ?? earliestPrice else { return [:] }
        let nav = await aggregatedValueHistory(
            isins: universe.isins,
            fallbackQuantityByIsin: universe.fallback,
            transactions: transactions,
            cutoffStr: start
        )
        let flows = await cashflowData(transactions: transactions)
        guard flows.isComplete else { return [:] }
        let index = PortfolioAnalytics.returnSeries(nav, cashflows: flows.cashflows)
            .map { (date: $0.date, value: 1 + $0.value / 100) }
        return MovingAverage.ratiosByWindow(index, at: dates)
    }

    // MARK: - Gold / Oil

    /// Gold/Oil ratio over the selected period, with moving-average ratios computed
    /// on the full stored history so a long window can use data before the period.
    func goldOilRatioData() async -> GoldOilRatioData {
        let index = await buildPriceIndex(for: [GoldIndexIsin, OilBrentIndexIsin])
        let full = GoldOilRatio.ratioSeries(
            gold: index[GoldIndexIsin] ?? [],
            oil: index[OilBrentIndexIsin] ?? []
        )
        let cutoff = selectedPeriod == .all ? "" : AppDateFormatter.yearMonthDay.string(from: selectedPeriod.comparisonDate)
        let points = full.compactMap { point -> (date: Date, value: Double)? in
            AppDateFormatter.yearMonthDay.date(from: point.date).map { ($0, point.value) }
        }
        let shown = zip(full, points).filter { $0.0.date >= cutoff }.map(\.1)
        return GoldOilRatioData(
            history: shown,
            movingAverageRatios: MovingAverage.ratiosByWindow(points, at: shown.map(\.date))
        )
    }

    /// Weekly gold and Brent history since the start, so the 7-year average has data.
    func downloadGoldOilLongHistory() async {
        async let gold = marketData.fetchGoldHistory(period: "max", interval: "1wk")
        async let oil = marketData.fetchOilBrentHistory(period: "max", interval: "1wk")
        let (goldPrices, oilPrices) = await (gold, oil)
        for price in goldPrices { await db.addPrice(price) }
        for price in oilPrices { await db.addPrice(price) }
    }
}

struct GoldOilRatioData {
    var history: [(date: Date, value: Double)] = []
    var movingAverageRatios: [MovingAverageWindow: [(date: Date, value: Double)]] = [:]
}
