import Foundation

extension AppViewModel {
    // MARK: - Reports
    func getHoldingDetails(forAccount accountId: Int) async -> [HoldingDetail] {
        await getAllHoldingDetailsByAccount()[accountId] ?? []
    }

    /// Resolves prices and ledgers in bulk, avoiding one database round-trip per holding.
    func getAllHoldingDetailsByAccount() async -> [Int: [HoldingDetail]] {
        clearRateCache()
        let comparisonDate = selectedPeriod.comparisonDate
        let comparisonDateStr = AppDateFormatter.yearMonthDay.string(from: comparisonDate)
        let todayStr = AppDateFormatter.todayString
        let histories = await db.getPriceHistory(forIsins: Array(Set(holdings.map(\.isin))))
        let pricesByIsin = Dictionary(grouping: histories, by: \.isin)
        let transactions = await db.getAllHoldingTransactions()
        let transactionsByPosition = Dictionary(grouping: transactions) { "\($0.accountId)|\($0.isin)" }
        var result: [Int: [HoldingDetail]] = [:]

        for holding in holdings {
            guard let instrument = instruments.first(where: { $0.isin == holding.isin }) else { continue }
            let priceHistory = pricesByIsin[holding.isin] ?? []
            let latestPrice = priceHistory.last
            let previousPrice: Price?
            if selectedPeriod == .oneDay, let currentDate = latestPrice?.date {
                previousPrice = priceHistory.last { $0.date < currentDate }
            } else {
                previousPrice = priceHistory.last { $0.date <= comparisonDateStr }
            }
            let txs = transactionsByPosition["\(holding.accountId)|\(holding.isin)"] ?? []
            let previousQty = PortfolioHistoryBuilder.quantityOnDate(
                transactions: txs.map { ($0.date, $0.quantityDelta) },
                date: comparisonDateStr,
                fallbackQuantity: holding.quantity
            )
            
            let quantity = effectiveQuantity(forIsin: holding.isin, originalQuantity: holding.quantity, currentPrice: latestPrice?.value)
            let currency = instrument.currency
            var currentValueEURConverted: Double? = nil
            if let price = latestPrice?.value {
                let value = quantity * price
                currentValueEURConverted = await convertToEUR(value: value, fromCurrency: currency, onDate: latestPrice?.date ?? todayStr)
            }
            var previousValueEURConverted: Double? = nil
            if previousQty > 0, let price = previousPrice?.value {
                let value = previousQty * price
                previousValueEURConverted = await convertToEUR(value: value, fromCurrency: currency, onDate: previousPrice?.date ?? comparisonDateStr)
            }
            
            result[holding.accountId, default: []].append(HoldingDetail(
                accountId: holding.accountId,
                isin: holding.isin,
                instrumentName: instrument.displayName,
                instrumentCurrency: currency,
                ticker: instrument.ticker,
                quantity: quantity,
                currentPrice: latestPrice?.value,
                previousPrice: previousPrice?.value,
                priceDate: latestPrice?.date,
                currentValueEUR: currentValueEURConverted,
                previousValueEUR: previousValueEURConverted
            ))
        }
        return result
    }
    
    func getQuadrantReport() async -> [QuadrantReportItem] {
        getQuadrantReport(from: await getAllHoldingDetailsByAccount())
    }

    func getQuadrantReport(
        from detailsByAccount: [Int: [HoldingDetail]]
    ) -> [QuadrantReportItem] {
        let groupedByIsin = Dictionary(grouping: detailsByAccount.values.flatMap { $0 }, by: \.isin)
        var detailsByQuadrant: [Int?: [HoldingDetail]] = [:]

        for (isin, details) in groupedByIsin {
            guard let first = details.first,
                  let instrument = instruments.first(where: { $0.isin == isin }) else { continue }
            let aggregate = HoldingDetail(
                accountId: 0,
                isin: isin,
                instrumentName: first.instrumentName,
                instrumentCurrency: first.instrumentCurrency,
                ticker: first.ticker,
                quantity: details.reduce(0) { $0 + $1.quantity },
                currentPrice: first.currentPrice,
                previousPrice: first.previousPrice,
                priceDate: first.priceDate,
                currentValueEUR: details.compactMap(\.currentValueEUR).reduce(0, +),
                previousValueEUR: details.compactMap(\.previousValueEUR).reduce(0, +)
            )
            detailsByQuadrant[instrument.quadrantId, default: []].append(aggregate)
        }

        var result = quadrants.compactMap { quadrant -> QuadrantReportItem? in
            guard let details = detailsByQuadrant[quadrant.id], !details.isEmpty else { return nil }
            return QuadrantReportItem(quadrant: quadrant, holdings: details)
        }
        if let details = detailsByQuadrant[nil], !details.isEmpty {
            result.append(QuadrantReportItem(quadrant: nil, holdings: details))
        }
        return result
    }
    
    /// Returns grand totals in EUR (all currencies converted)
    func getGrandTotalsEUR() async -> (current: Double, previous: Double) {
        let report = await getQuadrantReport()
        let current = report.map { $0.totalValueEUR }.reduce(0, +)
        let previous = report.map { $0.totalPreviousValueEUR }.reduce(0, +)
        return (current, previous)
    }
    
    /// Get gold spot price in EUR per ounce at a specific date
    func getGoldOuncePriceOnDate(_ date: Date) async -> Double? {
        let dateStr = AppDateFormatter.yearMonthDay.string(from: date)
        if let price = await db.getPriceOnOrBefore(forIsin: "VERACASH:GOLD_SPOT", date: dateStr) {
            return price.value * 31.1034768
        }
        return nil
    }
    
    /// Get grand totals in gold ounces (using respective gold prices for current and previous dates)
    func getGrandTotalsInGold() async -> (current: Double, previous: Double)? {
        guard let currentGoldPrice = await getCurrentGoldOuncePrice(), currentGoldPrice > 0 else { return nil }
        let comparisonDate = selectedPeriod.comparisonDate
        guard let previousGoldPrice = await getGoldOuncePriceOnDate(comparisonDate), previousGoldPrice > 0 else { return nil }
        let eurTotals = await getGrandTotalsEUR()
        let currentGoldOz = eurTotals.current / currentGoldPrice
        let previousGoldOz = eurTotals.previous / previousGoldPrice
        return (current: currentGoldOz, previous: previousGoldOz)
    }
    
    func getAllHoldingsWithQuantity() async -> [(isin: String, name: String, quantity: Double)] {
        let totals = Dictionary(grouping: holdings, by: \.isin)
            .mapValues { $0.reduce(0) { $0 + $1.quantity } }
        let latestPrices = await db.getLatestPrices(forIsins: instruments.map(\.isin))
        let priceByISIN = Dictionary(uniqueKeysWithValues: latestPrices.map { ($0.isin, $0.value) })
        return instruments.compactMap { instrument in
            let original = totals[instrument.isin] ?? 0
            let totalQuantity = demoMode.getTotalRandomizedQuantity(
                forIsin: instrument.isin,
                originalTotal: original,
                currentPrice: priceByISIN[instrument.isin]
            )
            if totalQuantity > 0 {
                return (isin: instrument.isin, name: instrument.displayName, quantity: totalQuantity)
            }
            return nil
        }
    }
}
