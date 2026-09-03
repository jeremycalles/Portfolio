import Foundation

extension AppViewModel {
    /// Price used as the period baseline. Falls back to the earliest known price so a
    /// holding without history before the cutoff is counted as unchanged, not omitted
    /// from previous totals (which inflated period %).
    private func comparisonPrice(forIsin isin: String, latestPrice: Price?, comparisonDateStr: String) async -> Price? {
        if selectedPeriod == .oneDay, let currentDate = latestPrice?.date {
            return await db.getPriceBefore(forIsin: isin, date: currentDate)
        }
        if let price = await db.getPriceOnOrBefore(forIsin: isin, date: comparisonDateStr) {
            return price
        }
        return await db.getEarliestPrice(forIsin: isin)
    }

    // MARK: - Reports
    func getHoldingDetails(forAccount accountId: Int) async -> [HoldingDetail] {
        clearRateCache()
        let accountHoldings = holdings.filter { $0.accountId == accountId }
        let comparisonDate = selectedPeriod.comparisonDate
        let comparisonDateStr = AppDateFormatter.yearMonthDay.string(from: comparisonDate)
        let todayStr = AppDateFormatter.yearMonthDay.string(from: Date())
        
        var result: [HoldingDetail] = []
        for holding in accountHoldings {
            guard let instrument = instruments.first(where: { $0.isin == holding.isin }) else { continue }
            
            let latestPrice = await db.getLatestPrice(forIsin: holding.isin)
            let previousPrice = await comparisonPrice(forIsin: holding.isin, latestPrice: latestPrice, comparisonDateStr: comparisonDateStr)
            let txs = await db.getHoldingTransactions(accountId: holding.accountId, isin: holding.isin)
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
            
            result.append(HoldingDetail(
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
        clearRateCache()
        var items: [QuadrantReportItem] = []
        let comparisonDate = selectedPeriod.comparisonDate
        let comparisonDateStr = AppDateFormatter.yearMonthDay.string(from: comparisonDate)
        let allTx = await db.getAllHoldingTransactions()
        var txByIsin: [String: [(date: String, quantityDelta: Double)]] = [:]
        for tx in allTx {
            txByIsin[tx.isin, default: []].append((tx.date, tx.quantityDelta))
        }
        
        for quadrant in quadrants {
            let quadrantInstruments = instruments.filter { $0.quadrantId == quadrant.id }
            var holdingDetails: [HoldingDetail] = []
            
            for instrument in quadrantInstruments {
                let latestPrice = await db.getLatestPrice(forIsin: instrument.isin)
                let totalQuantity = await effectiveTotalQuantity(forIsin: instrument.isin, currentPrice: latestPrice?.value)
                if totalQuantity > 0 {
                    let previousPrice = await comparisonPrice(forIsin: instrument.isin, latestPrice: latestPrice, comparisonDateStr: comparisonDateStr)
                    let realTotal = await db.getTotalQuantity(forIsin: instrument.isin)
                    let previousQty = PortfolioHistoryBuilder.quantityOnDate(
                        transactions: txByIsin[instrument.isin] ?? [],
                        date: comparisonDateStr,
                        fallbackQuantity: realTotal
                    )
                    let currency = instrument.currency
                    let currentValueEUR: Double? = latestPrice != nil ? await convertToEUR(value: totalQuantity * latestPrice!.value, fromCurrency: currency, onDate: latestPrice!.date) : nil
                    let previousValueEUR: Double? = (previousQty > 0 && previousPrice != nil) ? await convertToEUR(value: previousQty * previousPrice!.value, fromCurrency: currency, onDate: previousPrice!.date) : nil
                    holdingDetails.append(HoldingDetail(
                        accountId: 0,
                        isin: instrument.isin,
                        instrumentName: instrument.displayName,
                        instrumentCurrency: currency,
                        ticker: instrument.ticker,
                        quantity: totalQuantity,
                        currentPrice: latestPrice?.value,
                        previousPrice: previousPrice?.value,
                        priceDate: latestPrice?.date,
                        currentValueEUR: currentValueEUR,
                        previousValueEUR: previousValueEUR
                    ))
                }
            }
            
            if !holdingDetails.isEmpty {
                items.append(QuadrantReportItem(quadrant: quadrant, holdings: holdingDetails))
            }
        }
        
        let unassignedInstruments = instruments.filter { $0.quadrantId == nil }
        var unassignedDetails: [HoldingDetail] = []
        
        for instrument in unassignedInstruments {
            let latestPrice = await db.getLatestPrice(forIsin: instrument.isin)
            let totalQuantity = await effectiveTotalQuantity(forIsin: instrument.isin, currentPrice: latestPrice?.value)
            if totalQuantity > 0 {
                let previousPrice = await comparisonPrice(forIsin: instrument.isin, latestPrice: latestPrice, comparisonDateStr: comparisonDateStr)
                let realTotal = await db.getTotalQuantity(forIsin: instrument.isin)
                let previousQty = PortfolioHistoryBuilder.quantityOnDate(
                    transactions: txByIsin[instrument.isin] ?? [],
                    date: comparisonDateStr,
                    fallbackQuantity: realTotal
                )
                let currency = instrument.currency
                let currentValueEUR: Double? = latestPrice != nil ? await convertToEUR(value: totalQuantity * latestPrice!.value, fromCurrency: currency, onDate: latestPrice!.date) : nil
                let previousValueEUR: Double? = (previousQty > 0 && previousPrice != nil) ? await convertToEUR(value: previousQty * previousPrice!.value, fromCurrency: currency, onDate: previousPrice!.date) : nil
                unassignedDetails.append(HoldingDetail(
                    accountId: 0,
                    isin: instrument.isin,
                    instrumentName: instrument.displayName,
                    instrumentCurrency: currency,
                    ticker: instrument.ticker,
                    quantity: totalQuantity,
                    currentPrice: latestPrice?.value,
                    previousPrice: previousPrice?.value,
                    priceDate: latestPrice?.date,
                    currentValueEUR: currentValueEUR,
                    previousValueEUR: previousValueEUR
                ))
            }
        }
        
        if !unassignedDetails.isEmpty {
            items.append(QuadrantReportItem(quadrant: nil, holdings: unassignedDetails))
        }
        
        return items
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
        var result: [(isin: String, name: String, quantity: Double)] = []
        for instrument in instruments {
            let latestPrice = await db.getLatestPrice(forIsin: instrument.isin)
            let totalQuantity = await effectiveTotalQuantity(forIsin: instrument.isin, currentPrice: latestPrice?.value)
            if totalQuantity > 0 {
                result.append((isin: instrument.isin, name: instrument.displayName, quantity: totalQuantity))
            }
        }
        return result
    }
}
