import Foundation

extension AppViewModel {
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
            var previousPrice: Price?
            if selectedPeriod == .oneDay, let currentDate = latestPrice?.date {
                previousPrice = await db.getPriceBefore(forIsin: holding.isin, date: currentDate)
            } else {
                previousPrice = await db.getPriceOnOrBefore(forIsin: holding.isin, date: comparisonDateStr)
            }
            
            let quantity = effectiveQuantity(forIsin: holding.isin, originalQuantity: holding.quantity, currentPrice: latestPrice?.value)
            let currency = instrument.currency
            var currentValueEURConverted: Double? = nil
            if let price = latestPrice?.value {
                let value = quantity * price
                currentValueEURConverted = await convertToEUR(value: value, fromCurrency: currency, onDate: latestPrice?.date ?? todayStr)
            }
            var previousValueEURConverted: Double? = nil
            if let price = previousPrice?.value {
                let value = quantity * price
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
        
        for quadrant in quadrants {
            let quadrantInstruments = instruments.filter { $0.quadrantId == quadrant.id }
            var holdingDetails: [HoldingDetail] = []
            
            for instrument in quadrantInstruments {
                let latestPrice = await db.getLatestPrice(forIsin: instrument.isin)
                let totalQuantity = await effectiveTotalQuantity(forIsin: instrument.isin, currentPrice: latestPrice?.value)
                if totalQuantity > 0 {
                    let previousPrice: Price? = selectedPeriod == .oneDay && latestPrice != nil
                        ? await db.getPriceBefore(forIsin: instrument.isin, date: latestPrice!.date)
                        : await db.getPriceOnOrBefore(forIsin: instrument.isin, date: comparisonDateStr)
                    let currency = instrument.currency
                    let currentValueEUR: Double? = latestPrice != nil ? await convertToEUR(value: totalQuantity * latestPrice!.value, fromCurrency: currency, onDate: latestPrice!.date) : nil
                    let previousValueEUR: Double? = previousPrice != nil ? await convertToEUR(value: totalQuantity * previousPrice!.value, fromCurrency: currency, onDate: previousPrice!.date) : nil
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
                let previousPrice: Price? = selectedPeriod == .oneDay && latestPrice != nil
                    ? await db.getPriceBefore(forIsin: instrument.isin, date: latestPrice!.date)
                    : await db.getPriceOnOrBefore(forIsin: instrument.isin, date: comparisonDateStr)
                let currency = instrument.currency
                let currentValueEUR: Double? = latestPrice != nil ? await convertToEUR(value: totalQuantity * latestPrice!.value, fromCurrency: currency, onDate: latestPrice!.date) : nil
                let previousValueEUR: Double? = previousPrice != nil ? await convertToEUR(value: totalQuantity * previousPrice!.value, fromCurrency: currency, onDate: previousPrice!.date) : nil
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
