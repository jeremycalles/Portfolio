import Foundation

extension AppViewModel {
    // MARK: - Reports
    func getHoldingDetails(forAccount accountId: Int) -> [HoldingDetail] {
        clearRateCache()
        let accountHoldings = holdings.filter { $0.accountId == accountId }
        let comparisonDate = selectedPeriod.comparisonDate
        let comparisonDateStr = AppDateFormatter.yearMonthDay.string(from: comparisonDate)
        let todayStr = AppDateFormatter.yearMonthDay.string(from: Date())
        
        return accountHoldings.compactMap { holding -> HoldingDetail? in
            guard let instrument = instruments.first(where: { $0.isin == holding.isin }) else {
                return nil
            }
            
            let latestPrice = db.getLatestPrice(forIsin: holding.isin)
            
            // For 1Day, compare to price before the current price's date
            // For other periods, use the comparison date
            var previousPrice: Price?
            if selectedPeriod == .oneDay, let currentDate = latestPrice?.date {
                previousPrice = db.getPriceBefore(forIsin: holding.isin, date: currentDate)
            } else {
                previousPrice = db.getPriceOnOrBefore(forIsin: holding.isin, date: comparisonDateStr)
            }
            
            // Use effective quantity (randomized if demo mode is enabled, based on price to stay < 50,000)
            let quantity = effectiveQuantity(forIsin: holding.isin, originalQuantity: holding.quantity, currentPrice: latestPrice?.value)
            
            // Calculate EUR values - always use instrument.currency as source of truth
            let currency = instrument.currency
            let currentValueEUR: Double? = {
                guard let price = latestPrice?.value else { return nil }
                let value = quantity * price
                return convertToEUR(value: value, fromCurrency: currency, onDate: latestPrice?.date ?? todayStr)
            }()
            let previousValueEUR: Double? = {
                guard let price = previousPrice?.value else { return nil }
                let value = quantity * price
                return convertToEUR(value: value, fromCurrency: currency, onDate: previousPrice?.date ?? comparisonDateStr)
            }()
            
            return HoldingDetail(
                accountId: holding.accountId,
                isin: holding.isin,
                instrumentName: instrument.displayName,
                instrumentCurrency: currency,
                ticker: instrument.ticker,
                quantity: quantity,
                currentPrice: latestPrice?.value,
                previousPrice: previousPrice?.value,
                priceDate: latestPrice?.date,
                currentValueEUR: currentValueEUR,
                previousValueEUR: previousValueEUR
            )
        }
    }
    
    func getQuadrantReport() -> [QuadrantReportItem] {
        clearRateCache()
        var items: [QuadrantReportItem] = []
        let comparisonDate = selectedPeriod.comparisonDate
        let comparisonDateStr = AppDateFormatter.yearMonthDay.string(from: comparisonDate)
        let todayStr = AppDateFormatter.yearMonthDay.string(from: Date())
        
        // Helper to get previous price based on period
        func getPreviousPrice(forIsin isin: String, currentDate: String?) -> Price? {
            if selectedPeriod == .oneDay, let date = currentDate {
                return db.getPriceBefore(forIsin: isin, date: date)
            } else {
                return db.getPriceOnOrBefore(forIsin: isin, date: comparisonDateStr)
            }
        }
        
        // Helper to create HoldingDetail with EUR values
        func createHoldingDetail(instrument: Instrument, quantity: Double) -> HoldingDetail {
            let latestPrice = db.getLatestPrice(forIsin: instrument.isin)
            let previousPrice = getPreviousPrice(forIsin: instrument.isin, currentDate: latestPrice?.date)
            // Always use instrument.currency as source of truth
            let currency = instrument.currency
            
            // Calculate EUR values
            let currentValueEUR: Double? = {
                guard let price = latestPrice?.value else { return nil }
                let value = quantity * price
                return convertToEUR(value: value, fromCurrency: currency, onDate: latestPrice?.date ?? todayStr)
            }()
            let previousValueEUR: Double? = {
                guard let price = previousPrice?.value else { return nil }
                let value = quantity * price
                return convertToEUR(value: value, fromCurrency: currency, onDate: previousPrice?.date ?? comparisonDateStr)
            }()
            
            return HoldingDetail(
                accountId: 0,
                isin: instrument.isin,
                instrumentName: instrument.displayName,
                instrumentCurrency: currency,
                ticker: instrument.ticker,
                quantity: quantity,
                currentPrice: latestPrice?.value,
                previousPrice: previousPrice?.value,
                priceDate: latestPrice?.date,
                currentValueEUR: currentValueEUR,
                previousValueEUR: previousValueEUR
            )
        }
        
        // Get instruments grouped by quadrant
        for quadrant in quadrants {
            let quadrantInstruments = instruments.filter { $0.quadrantId == quadrant.id }
            var holdingDetails: [HoldingDetail] = []
            
            for instrument in quadrantInstruments {
                // Get current price first to calculate effective quantity (for demo mode value < 50,000)
                let latestPrice = db.getLatestPrice(forIsin: instrument.isin)
                // Use effective total quantity (randomized if demo mode is enabled, based on price)
                let totalQuantity = effectiveTotalQuantity(forIsin: instrument.isin, currentPrice: latestPrice?.value)
                if totalQuantity > 0 {
                    holdingDetails.append(createHoldingDetail(instrument: instrument, quantity: totalQuantity))
                }
            }
            
            if !holdingDetails.isEmpty {
                items.append(QuadrantReportItem(quadrant: quadrant, holdings: holdingDetails))
            }
        }
        
        // Unassigned instruments
        let unassignedInstruments = instruments.filter { $0.quadrantId == nil }
        var unassignedDetails: [HoldingDetail] = []
        
        for instrument in unassignedInstruments {
            // Get current price first to calculate effective quantity (for demo mode value < 50,000)
            let latestPrice = db.getLatestPrice(forIsin: instrument.isin)
            // Use effective total quantity (randomized if demo mode is enabled, based on price)
            let totalQuantity = effectiveTotalQuantity(forIsin: instrument.isin, currentPrice: latestPrice?.value)
            if totalQuantity > 0 {
                unassignedDetails.append(createHoldingDetail(instrument: instrument, quantity: totalQuantity))
            }
        }
        
        if !unassignedDetails.isEmpty {
            items.append(QuadrantReportItem(quadrant: nil, holdings: unassignedDetails))
        }
        
        return items
    }
    
    // Legacy: returns totals grouped by currency
    func getGrandTotals() -> (current: [String: Double], previous: [String: Double]) {
        let report = getQuadrantReport()
        var currentTotals: [String: Double] = [:]
        var previousTotals: [String: Double] = [:]
        
        for item in report {
            for (currency, value) in item.totalValue {
                currentTotals[currency, default: 0] += value
            }
            for (currency, value) in item.totalPreviousValue {
                previousTotals[currency, default: 0] += value
            }
        }
        
        return (currentTotals, previousTotals)
    }
    
    /// Returns grand totals in EUR (all currencies converted)
    func getGrandTotalsEUR() -> (current: Double, previous: Double) {
        let report = getQuadrantReport()
        let current = report.map { $0.totalValueEUR }.reduce(0, +)
        let previous = report.map { $0.totalPreviousValueEUR }.reduce(0, +)
        return (current, previous)
    }
    
    /// Get gold spot price in EUR per ounce at a specific date
    func getGoldOuncePriceOnDate(_ date: Date) -> Double? {
        let dateStr = AppDateFormatter.yearMonthDay.string(from: date)
        
        if let price = db.getPriceOnOrBefore(forIsin: "VERACASH:GOLD_SPOT", date: dateStr) {
            // VERACASH:GOLD_SPOT is price per gram, convert to per ounce (1 troy oz = 31.1034768 g)
            return price.value * 31.1034768
        }
        return nil
    }
    
    /// Get grand totals in gold ounces (using respective gold prices for current and previous dates)
    func getGrandTotalsInGold() -> (current: Double, previous: Double)? {
        // Get current gold price for current value
        guard let currentGoldPrice = getCurrentGoldOuncePrice(), currentGoldPrice > 0 else {
            return nil
        }
        
        // Get historical gold price for previous value (at comparison date)
        let comparisonDate = selectedPeriod.comparisonDate
        guard let previousGoldPrice = getGoldOuncePriceOnDate(comparisonDate), previousGoldPrice > 0 else {
            return nil
        }
        
        let eurTotals = getGrandTotalsEUR()
        
        // Convert current EUR to gold oz using current gold price
        // Convert previous EUR to gold oz using historical gold price
        let currentGoldOz = eurTotals.current / currentGoldPrice
        let previousGoldOz = eurTotals.previous / previousGoldPrice
        
        return (current: currentGoldOz, previous: previousGoldOz)
    }
    
    // Get all holdings with their details for display
    func getAllHoldingsWithQuantity() -> [(isin: String, name: String, quantity: Double)] {
        var result: [(isin: String, name: String, quantity: Double)] = []
        
        for instrument in instruments {
            // Get current price for demo mode quantity calculation
            let latestPrice = db.getLatestPrice(forIsin: instrument.isin)
            // Use effective total quantity (randomized if demo mode is enabled, based on price to stay < 50,000)
            let totalQuantity = effectiveTotalQuantity(forIsin: instrument.isin, currentPrice: latestPrice?.value)
            if totalQuantity > 0 {
                result.append((isin: instrument.isin, name: instrument.displayName, quantity: totalQuantity))
            }
        }
        
        return result
    }
}
