import Foundation

extension AppViewModel {
    // MARK: - Portfolio History
    func getPortfolioValueHistory() -> [(date: Date, value: Double)] {
        // Get cutoff date based on selected period
        let cutoffDate = selectedPeriod.comparisonDate
        let cutoffStr = AppDateFormatter.yearMonthDay.string(from: cutoffDate)
        
        // Collect holdings and find the earliest date when ALL instruments have data
        var holdingQuantities: [(isin: String, quantity: Double)] = []
        var earliestDatePerInstrument: [String] = []
        
        for instrument in instruments {
            // Get current price for demo mode quantity calculation
            let latestPrice = db.getLatestPrice(forIsin: instrument.isin)
            // Use effective total quantity (randomized if demo mode is enabled, based on price to stay < 50,000)
            let totalQuantity = effectiveTotalQuantity(forIsin: instrument.isin, currentPrice: latestPrice?.value)
            if totalQuantity > 0 {
                holdingQuantities.append((isin: instrument.isin, quantity: totalQuantity))
                let history = db.getPriceHistory(forIsin: instrument.isin)
                // Get the earliest date for this instrument (history is sorted desc, so last is earliest)
                if let earliestPrice = history.last {
                    earliestDatePerInstrument.append(earliestPrice.date)
                }
            }
        }
        
        // Find the latest "earliest date" - this is when ALL instruments have data
        let effectiveStartDate = earliestDatePerInstrument.max() ?? cutoffStr
        // Use the later of: comparison date or effective start date
        let actualStartDate = max(cutoffStr, effectiveStartDate)
        
        // Collect all unique dates from price history starting from actualStartDate
        var allDates: Set<String> = []
        for holding in holdingQuantities {
            let history = db.getPriceHistory(forIsin: holding.isin)
            for price in history {
                if price.date >= actualStartDate {
                    allDates.insert(price.date)
                }
            }
        }
        
        // Sort dates
        let sortedDates = allDates.sorted()
        
        // Calculate portfolio value for each date (only include if ALL holdings have price data)
        // All values are converted to EUR
        var portfolioHistory: [(date: Date, value: Double)] = []
        
        for dateStr in sortedDates {
            var totalValueEUR = 0.0
            var allHaveData = true
            
            for holding in holdingQuantities {
                // Get price on or before this date
                if let price = db.getPriceOnOrBefore(forIsin: holding.isin, date: dateStr) {
                    let holdingValue = holding.quantity * price.value
                    // Always use instrument currency as source of truth
                    let currency = getInstrumentCurrency(forIsin: holding.isin)
                    let valueInEUR = convertToEUR(value: holdingValue, fromCurrency: currency, onDate: dateStr)
                    totalValueEUR += valueInEUR
                } else {
                    allHaveData = false
                    break
                }
            }
            
            if allHaveData && totalValueEUR > 0, let date = AppDateFormatter.yearMonthDay.date(from: dateStr) {
                portfolioHistory.append((date: date, value: totalValueEUR))
            }
        }
        
        return portfolioHistory
    }
    
    /// Get portfolio value history in gold ounces (converts EUR history using gold prices at each date)
    func getGoldOzHistory() -> [(date: Date, value: Double)] {
        let eurHistory = getPortfolioValueHistory()
        if eurHistory.isEmpty { return [] }
        
        var goldHistory: [(date: Date, value: Double)] = []
        for point in eurHistory {
            let dateStr = AppDateFormatter.yearMonthDay.string(from: point.date)
            // Get gold price at this date (price per gram → per ounce)
            if let goldPrice = db.getPriceOnOrBefore(forIsin: "VERACASH:GOLD_SPOT", date: dateStr),
               goldPrice.value > 0 {
                let goldOuncePrice = goldPrice.value * 31.1034768
                let goldOz = point.value / goldOuncePrice
                goldHistory.append((date: point.date, value: goldOz))
            }
        }
        return goldHistory
    }
    
    /// S&P 500 comparison: same-date series as portfolio history, values = initial portfolio value scaled by S&P performance.
    /// Used for macOS dashboard chart; returns [] if no portfolio history or no S&P data.
    func getSP500ComparisonHistory() -> [(date: Date, value: Double)] {
        let portfolioHistory = getPortfolioValueHistory()
        guard let first = portfolioHistory.first, first.value > 0 else { return [] }
        let (date0, value0) = (first.date, first.value)
        let date0Str = AppDateFormatter.yearMonthDay.string(from: date0)
        guard let spAtStart = db.getPriceOnOrBefore(forIsin: SP500IndexIsin, date: date0Str), spAtStart.value > 0 else { return [] }
        
        var result: [(date: Date, value: Double)] = []
        for point in portfolioHistory {
            let dateStr = AppDateFormatter.yearMonthDay.string(from: point.date)
            guard let sp = db.getPriceOnOrBefore(forIsin: SP500IndexIsin, date: dateStr), sp.value > 0 else { continue }
            let scaled = value0 * (sp.value / spAtStart.value)
            result.append((date: point.date, value: scaled))
        }
        return result
    }

    /// Gold comparison: same-date series as portfolio history, values = initial portfolio value scaled by Gold performance.
    func getGoldComparisonHistory() -> [(date: Date, value: Double)] {
        let portfolioHistory = getPortfolioValueHistory()
        guard let first = portfolioHistory.first, first.value > 0 else { return [] }
        let (date0, value0) = (first.date, first.value)
        let date0Str = AppDateFormatter.yearMonthDay.string(from: date0)
        guard let goldAtStart = db.getPriceOnOrBefore(forIsin: GoldIndexIsin, date: date0Str), goldAtStart.value > 0 else { return [] }
        
        var result: [(date: Date, value: Double)] = []
        for point in portfolioHistory {
            let dateStr = AppDateFormatter.yearMonthDay.string(from: point.date)
            guard let gold = db.getPriceOnOrBefore(forIsin: GoldIndexIsin, date: dateStr), gold.value > 0 else { continue }
            let scaled = value0 * (gold.value / goldAtStart.value)
            result.append((date: point.date, value: scaled))
        }
        return result
    }

    /// MSCI World comparison: same-date series as portfolio history, values = initial portfolio value scaled by MSCI World performance.
    func getMSCIWorldComparisonHistory() -> [(date: Date, value: Double)] {
        let portfolioHistory = getPortfolioValueHistory()
        guard let first = portfolioHistory.first, first.value > 0 else { return [] }
        let (date0, value0) = (first.date, first.value)
        let date0Str = AppDateFormatter.yearMonthDay.string(from: date0)
        guard let msciAtStart = db.getPriceOnOrBefore(forIsin: MSCIWorldIndexIsin, date: date0Str), msciAtStart.value > 0 else { return [] }
        
        var result: [(date: Date, value: Double)] = []
        for point in portfolioHistory {
            let dateStr = AppDateFormatter.yearMonthDay.string(from: point.date)
            guard let msci = db.getPriceOnOrBefore(forIsin: MSCIWorldIndexIsin, date: dateStr), msci.value > 0 else { continue }
            let scaled = value0 * (msci.value / msciAtStart.value)
            result.append((date: point.date, value: scaled))
        }
        return result
    }
    
    func getQuadrantValueHistory(quadrantId: Int?) -> [(date: Date, value: Double)] {
        // Get cutoff date based on selected period
        let cutoffDate = selectedPeriod.comparisonDate
        let cutoffStr = AppDateFormatter.yearMonthDay.string(from: cutoffDate)
        
        // Get instruments for this quadrant
        let quadrantInstruments = instruments.filter { $0.quadrantId == quadrantId }
        
        // Collect holdings for this quadrant
        var holdingQuantities: [(isin: String, quantity: Double)] = []
        var earliestDatePerInstrument: [String] = []
        
        for instrument in quadrantInstruments {
            // Get current price for demo mode quantity calculation
            let latestPrice = db.getLatestPrice(forIsin: instrument.isin)
            // Use effective total quantity (randomized if demo mode is enabled, based on price to stay < 50,000)
            let totalQuantity = effectiveTotalQuantity(forIsin: instrument.isin, currentPrice: latestPrice?.value)
            if totalQuantity > 0 {
                holdingQuantities.append((isin: instrument.isin, quantity: totalQuantity))
                let history = db.getPriceHistory(forIsin: instrument.isin)
                if let earliestPrice = history.last {
                    earliestDatePerInstrument.append(earliestPrice.date)
                }
            }
        }
        
        // If no holdings in this quadrant, return empty
        if holdingQuantities.isEmpty {
            return []
        }
        
        // Find the latest "earliest date" - when ALL instruments in quadrant have data
        let effectiveStartDate = earliestDatePerInstrument.max() ?? cutoffStr
        let actualStartDate = max(cutoffStr, effectiveStartDate)
        
        // Collect all unique dates from price history
        var allDates: Set<String> = []
        for holding in holdingQuantities {
            let history = db.getPriceHistory(forIsin: holding.isin)
            for price in history {
                if price.date >= actualStartDate {
                    allDates.insert(price.date)
                }
            }
        }
        
        let sortedDates = allDates.sorted()
        
        // Calculate quadrant value for each date (converted to EUR)
        var quadrantHistory: [(date: Date, value: Double)] = []
        
        for dateStr in sortedDates {
            var totalValueEUR = 0.0
            var allHaveData = true
            
            for holding in holdingQuantities {
                if let price = db.getPriceOnOrBefore(forIsin: holding.isin, date: dateStr) {
                    let holdingValue = holding.quantity * price.value
                    // Always use instrument currency as source of truth
                    let currency = getInstrumentCurrency(forIsin: holding.isin)
                    let valueInEUR = convertToEUR(value: holdingValue, fromCurrency: currency, onDate: dateStr)
                    totalValueEUR += valueInEUR
                } else {
                    allHaveData = false
                    break
                }
            }
            
            if allHaveData && totalValueEUR > 0, let date = AppDateFormatter.yearMonthDay.date(from: dateStr) {
                quadrantHistory.append((date: date, value: totalValueEUR))
            }
        }
        
        return quadrantHistory
    }
    
    /// Convert quadrant value history from EUR to gold ounces using Veracash gold spot price
    func getQuadrantValueHistoryInGold(quadrantId: Int?) -> [(date: Date, value: Double)] {
        // Get EUR history
        let eurHistory = getQuadrantValueHistory(quadrantId: quadrantId)
        if eurHistory.isEmpty { return [] }
        
        // Get gold price history (VERACASH:GOLD_SPOT is price per gram)
        let goldPriceHistory = db.getPriceHistory(forIsin: "VERACASH:GOLD_SPOT")
        
        // Build a lookup of gold prices by date
        var goldPricesByDate: [String: Double] = [:]
        for price in goldPriceHistory {
            // Convert gram price to ounce price (1 troy ounce = 31.1034768 grams)
            goldPricesByDate[price.date] = price.value * 31.1034768
        }
        
        // If no gold prices, return empty
        if goldPricesByDate.isEmpty { return [] }
        
        // Convert each EUR value to gold ounces
        var goldHistory: [(date: Date, value: Double)] = []
        var lastKnownGoldPrice: Double? = nil
        
        for point in eurHistory {
            let dateStr = AppDateFormatter.yearMonthDay.string(from: point.date)
            
            // Get gold price for this date, or use last known price
            let goldOuncePrice: Double
            if let price = goldPricesByDate[dateStr] {
                goldOuncePrice = price
                lastKnownGoldPrice = price
            } else if let lastPrice = lastKnownGoldPrice {
                goldOuncePrice = lastPrice
            } else {
                // Find the closest earlier date
                let sortedDates = goldPricesByDate.keys.sorted()
                if let closestDate = sortedDates.last(where: { $0 <= dateStr }),
                   let price = goldPricesByDate[closestDate] {
                    goldOuncePrice = price
                    lastKnownGoldPrice = price
                } else {
                    continue // Skip if no gold price available
                }
            }
            
            // Convert EUR to gold ounces
            if goldOuncePrice > 0 {
                let goldOunces = point.value / goldOuncePrice
                goldHistory.append((date: point.date, value: goldOunces))
            }
        }
        
        return goldHistory
    }
    
    func getHoldingValueHistory(isin: String, quantity: Double) -> [(date: Date, value: Double)] {
        // Get cutoff date based on selected period
        let cutoffDate = selectedPeriod.comparisonDate
        let cutoffStr = AppDateFormatter.yearMonthDay.string(from: cutoffDate)
        
        // Get price history for this instrument
        let priceHistory = db.getPriceHistory(forIsin: isin)
        let instrumentCurrency = getInstrumentCurrency(forIsin: isin)
        
        // Get current price for demo mode quantity calculation
        let latestPrice = db.getLatestPrice(forIsin: isin)
        // Use effective quantity (randomized if demo mode is enabled, based on price to stay < 50,000)
        let effectiveQty = effectiveQuantity(forIsin: isin, originalQuantity: quantity, currentPrice: latestPrice?.value)
        
        // Filter to dates within period and calculate value (converted to EUR)
        var holdingHistory: [(date: Date, value: Double)] = []
        
        for price in priceHistory.reversed() {  // Reverse to get chronological order
            if price.date >= cutoffStr {
                if let date = AppDateFormatter.yearMonthDay.date(from: price.date) {
                    let holdingValue = effectiveQty * price.value
                    // Always use instrument currency as source of truth
                    let valueInEUR = convertToEUR(value: holdingValue, fromCurrency: instrumentCurrency, onDate: price.date)
                    holdingHistory.append((date: date, value: valueInEUR))
                }
            }
        }
        
        return holdingHistory
    }
    
    func getAccountValueHistory(accountId: Int) -> [(date: Date, value: Double)] {
        // Get cutoff date based on selected period
        let cutoffDate = selectedPeriod.comparisonDate
        let cutoffStr = AppDateFormatter.yearMonthDay.string(from: cutoffDate)
        
        // Get holdings for this account
        let accountHoldings = holdings.filter { $0.accountId == accountId }
        
        // Collect holdings with quantities (using effective quantities if demo mode is enabled)
        var holdingQuantities: [(isin: String, quantity: Double)] = []
        var earliestDatePerInstrument: [String] = []
        
        for holding in accountHoldings {
            if holding.quantity > 0 {
                // Get current price for demo mode quantity calculation
                let latestPrice = db.getLatestPrice(forIsin: holding.isin)
                // Use effective quantity (randomized if demo mode is enabled, based on price to stay < 50,000)
                let quantity = effectiveQuantity(forIsin: holding.isin, originalQuantity: holding.quantity, currentPrice: latestPrice?.value)
                holdingQuantities.append((isin: holding.isin, quantity: quantity))
                let history = db.getPriceHistory(forIsin: holding.isin)
                if let earliestPrice = history.last {
                    earliestDatePerInstrument.append(earliestPrice.date)
                }
            }
        }
        
        // If no holdings in this account, return empty
        if holdingQuantities.isEmpty {
            return []
        }
        
        // Find the latest "earliest date" - when ALL instruments in account have data
        let effectiveStartDate = earliestDatePerInstrument.max() ?? cutoffStr
        let actualStartDate = max(cutoffStr, effectiveStartDate)
        
        // Collect all unique dates from price history
        var allDates: Set<String> = []
        for holding in holdingQuantities {
            let history = db.getPriceHistory(forIsin: holding.isin)
            for price in history {
                if price.date >= actualStartDate {
                    allDates.insert(price.date)
                }
            }
        }
        
        let sortedDates = allDates.sorted()
        
        // Calculate account value for each date (converted to EUR)
        var accountHistory: [(date: Date, value: Double)] = []
        
        for dateStr in sortedDates {
            var totalValueEUR = 0.0
            var allHaveData = true
            
            for holding in holdingQuantities {
                if let price = db.getPriceOnOrBefore(forIsin: holding.isin, date: dateStr) {
                    let holdingValue = holding.quantity * price.value
                    // Always use instrument currency as source of truth
                    let currency = getInstrumentCurrency(forIsin: holding.isin)
                    let valueInEUR = convertToEUR(value: holdingValue, fromCurrency: currency, onDate: dateStr)
                    totalValueEUR += valueInEUR
                } else {
                    allHaveData = false
                    break
                }
            }
            
            if allHaveData && totalValueEUR > 0, let date = AppDateFormatter.yearMonthDay.date(from: dateStr) {
                accountHistory.append((date: date, value: totalValueEUR))
            }
        }
        
        return accountHistory
    }
}
