import Foundation

extension AppViewModel {
    // MARK: - Price Index Helpers
    
    /// Builds an ascending-sorted price index for each ISIN, loading all data from DB once.
    private func buildPriceIndex(for isins: [String]) -> [String: [(date: String, value: Double)]] {
        var index: [String: [(date: String, value: Double)]] = [:]
        index.reserveCapacity(isins.count)
        for isin in isins {
            let history = db.getPriceHistory(forIsin: isin) // sorted desc
            index[isin] = history.map { ($0.date, $0.value) }.reversed() // ascending
        }
        return index
    }
    
    /// Binary search for the last entry whose date <= target date.
    private func priceLookup(index: [(date: String, value: Double)], onOrBefore date: String) -> Double? {
        guard !index.isEmpty else { return nil }
        // Binary search: find rightmost entry where entry.date <= date
        var lo = 0, hi = index.count - 1
        var result: Int? = nil
        while lo <= hi {
            let mid = (lo + hi) / 2
            if index[mid].date <= date {
                result = mid
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        guard let idx = result else { return nil }
        return index[idx].value
    }
    
    /// Collects all unique dates from a price index that are >= startDate.
    private func collectDates(from priceIndex: [String: [(date: String, value: Double)]], isins: [String], startDate: String) -> [String] {
        var allDates: Set<String> = []
        for isin in isins {
            guard let entries = priceIndex[isin] else { continue }
            for entry in entries {
                if entry.date >= startDate {
                    allDates.insert(entry.date)
                }
            }
        }
        return allDates.sorted()
    }
    
    /// Gets the earliest date (first entry) for each ISIN in the index.
    private func earliestDates(from priceIndex: [String: [(date: String, value: Double)]], isins: [String]) -> [String] {
        isins.compactMap { priceIndex[$0]?.first?.date }
    }
    
    // MARK: - Portfolio History
    func getPortfolioValueHistory() -> [(date: Date, value: Double)] {
        clearRateCache()
        let cutoffDate = selectedPeriod.comparisonDate
        let cutoffStr = AppDateFormatter.yearMonthDay.string(from: cutoffDate)
        
        // Collect holdings
        var holdingQuantities: [(isin: String, quantity: Double)] = []
        for instrument in instruments {
            let latestPrice = db.getLatestPrice(forIsin: instrument.isin)
            let totalQuantity = effectiveTotalQuantity(forIsin: instrument.isin, currentPrice: latestPrice?.value)
            if totalQuantity > 0 {
                holdingQuantities.append((isin: instrument.isin, quantity: totalQuantity))
            }
        }
        
        let isins = holdingQuantities.map { $0.isin }
        let priceIndex = buildPriceIndex(for: isins)
        
        // Find effective start date
        let earliestPerInstrument = earliestDates(from: priceIndex, isins: isins)
        let effectiveStartDate = earliestPerInstrument.max() ?? cutoffStr
        let actualStartDate = max(cutoffStr, effectiveStartDate)
        
        let sortedDates = collectDates(from: priceIndex, isins: isins, startDate: actualStartDate)
        
        var portfolioHistory: [(date: Date, value: Double)] = []
        portfolioHistory.reserveCapacity(sortedDates.count)
        
        for dateStr in sortedDates {
            var totalValueEUR = 0.0
            var allHaveData = true
            
            for holding in holdingQuantities {
                if let priceValue = priceLookup(index: priceIndex[holding.isin] ?? [], onOrBefore: dateStr) {
                    let holdingValue = holding.quantity * priceValue
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
        
        let goldIndex = buildPriceIndex(for: ["VERACASH:GOLD_SPOT"])["VERACASH:GOLD_SPOT"] ?? []
        
        var goldHistory: [(date: Date, value: Double)] = []
        goldHistory.reserveCapacity(eurHistory.count)
        for point in eurHistory {
            let dateStr = AppDateFormatter.yearMonthDay.string(from: point.date)
            if let gramPrice = priceLookup(index: goldIndex, onOrBefore: dateStr), gramPrice > 0 {
                let goldOuncePrice = gramPrice * 31.1034768
                let goldOz = point.value / goldOuncePrice
                goldHistory.append((date: point.date, value: goldOz))
            }
        }
        return goldHistory
    }
    
    /// Benchmark comparison helper: scales initial portfolio value by benchmark performance.
    private func benchmarkComparisonHistory(benchmarkIsin: String) -> [(date: Date, value: Double)] {
        let portfolioHistory = getPortfolioValueHistory()
        guard let first = portfolioHistory.first, first.value > 0 else { return [] }
        let (date0, value0) = (first.date, first.value)
        let date0Str = AppDateFormatter.yearMonthDay.string(from: date0)
        
        let benchIndex = buildPriceIndex(for: [benchmarkIsin])[benchmarkIsin] ?? []
        guard let benchAtStart = priceLookup(index: benchIndex, onOrBefore: date0Str), benchAtStart > 0 else { return [] }
        
        var result: [(date: Date, value: Double)] = []
        result.reserveCapacity(portfolioHistory.count)
        for point in portfolioHistory {
            let dateStr = AppDateFormatter.yearMonthDay.string(from: point.date)
            guard let benchValue = priceLookup(index: benchIndex, onOrBefore: dateStr), benchValue > 0 else { continue }
            let scaled = value0 * (benchValue / benchAtStart)
            result.append((date: point.date, value: scaled))
        }
        return result
    }
    
    /// S&P 500 comparison: same-date series as portfolio history, values = initial portfolio value scaled by S&P performance.
    func getSP500ComparisonHistory() -> [(date: Date, value: Double)] {
        benchmarkComparisonHistory(benchmarkIsin: SP500IndexIsin)
    }

    /// Gold comparison: same-date series as portfolio history, values = initial portfolio value scaled by Gold performance.
    func getGoldComparisonHistory() -> [(date: Date, value: Double)] {
        benchmarkComparisonHistory(benchmarkIsin: GoldIndexIsin)
    }

    /// MSCI World comparison: same-date series as portfolio history, values = initial portfolio value scaled by MSCI World performance.
    func getMSCIWorldComparisonHistory() -> [(date: Date, value: Double)] {
        benchmarkComparisonHistory(benchmarkIsin: MSCIWorldIndexIsin)
    }
    
    func getQuadrantValueHistory(quadrantId: Int?) -> [(date: Date, value: Double)] {
        clearRateCache()
        let cutoffDate = selectedPeriod.comparisonDate
        let cutoffStr = AppDateFormatter.yearMonthDay.string(from: cutoffDate)
        
        let quadrantInstruments = instruments.filter { $0.quadrantId == quadrantId }
        
        var holdingQuantities: [(isin: String, quantity: Double)] = []
        for instrument in quadrantInstruments {
            let latestPrice = db.getLatestPrice(forIsin: instrument.isin)
            let totalQuantity = effectiveTotalQuantity(forIsin: instrument.isin, currentPrice: latestPrice?.value)
            if totalQuantity > 0 {
                holdingQuantities.append((isin: instrument.isin, quantity: totalQuantity))
            }
        }
        
        if holdingQuantities.isEmpty { return [] }
        
        let isins = holdingQuantities.map { $0.isin }
        let priceIndex = buildPriceIndex(for: isins)
        
        let earliestPerInstrument = earliestDates(from: priceIndex, isins: isins)
        let effectiveStartDate = earliestPerInstrument.max() ?? cutoffStr
        let actualStartDate = max(cutoffStr, effectiveStartDate)
        
        let sortedDates = collectDates(from: priceIndex, isins: isins, startDate: actualStartDate)
        
        var quadrantHistory: [(date: Date, value: Double)] = []
        quadrantHistory.reserveCapacity(sortedDates.count)
        
        for dateStr in sortedDates {
            var totalValueEUR = 0.0
            var allHaveData = true
            
            for holding in holdingQuantities {
                if let priceValue = priceLookup(index: priceIndex[holding.isin] ?? [], onOrBefore: dateStr) {
                    let holdingValue = holding.quantity * priceValue
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
        let eurHistory = getQuadrantValueHistory(quadrantId: quadrantId)
        if eurHistory.isEmpty { return [] }
        
        // Build a lookup of gold prices by date (already done efficiently via buildPriceIndex)
        let goldIndex = buildPriceIndex(for: ["VERACASH:GOLD_SPOT"])["VERACASH:GOLD_SPOT"] ?? []
        if goldIndex.isEmpty { return [] }
        
        // Build a dictionary for exact-date lookups + fallback to binary search
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
            } else {
                // Binary search fallback
                if let gramPrice = priceLookup(index: goldIndex, onOrBefore: dateStr), gramPrice > 0 {
                    let ouncePrice = gramPrice * 31.1034768
                    goldOuncePrice = ouncePrice
                    lastKnownGoldPrice = ouncePrice
                } else {
                    continue
                }
            }
            
            if goldOuncePrice > 0 {
                let goldOunces = point.value / goldOuncePrice
                goldHistory.append((date: point.date, value: goldOunces))
            }
        }
        
        return goldHistory
    }
    
    func getHoldingValueHistory(isin: String, quantity: Double) -> [(date: Date, value: Double)] {
        clearRateCache()
        let cutoffDate = selectedPeriod.comparisonDate
        let cutoffStr = AppDateFormatter.yearMonthDay.string(from: cutoffDate)
        
        let priceIndex = buildPriceIndex(for: [isin])[isin] ?? [] // ascending
        let instrumentCurrency = getInstrumentCurrency(forIsin: isin)
        
        // Get current price for demo mode quantity calculation
        let latestPrice = priceIndex.last?.value
        let effectiveQty = effectiveQuantity(forIsin: isin, originalQuantity: quantity, currentPrice: latestPrice)
        
        var holdingHistory: [(date: Date, value: Double)] = []
        holdingHistory.reserveCapacity(priceIndex.count)
        
        for entry in priceIndex {
            if entry.date >= cutoffStr {
                if let date = AppDateFormatter.yearMonthDay.date(from: entry.date) {
                    let holdingValue = effectiveQty * entry.value
                    let valueInEUR = convertToEUR(value: holdingValue, fromCurrency: instrumentCurrency, onDate: entry.date)
                    holdingHistory.append((date: date, value: valueInEUR))
                }
            }
        }
        
        return holdingHistory
    }
    
    func getAccountValueHistory(accountId: Int) -> [(date: Date, value: Double)] {
        clearRateCache()
        let cutoffDate = selectedPeriod.comparisonDate
        let cutoffStr = AppDateFormatter.yearMonthDay.string(from: cutoffDate)
        
        let accountHoldings = holdings.filter { $0.accountId == accountId }
        
        var holdingQuantities: [(isin: String, quantity: Double)] = []
        for holding in accountHoldings {
            if holding.quantity > 0 {
                let latestPrice = db.getLatestPrice(forIsin: holding.isin)
                let quantity = effectiveQuantity(forIsin: holding.isin, originalQuantity: holding.quantity, currentPrice: latestPrice?.value)
                holdingQuantities.append((isin: holding.isin, quantity: quantity))
            }
        }
        
        if holdingQuantities.isEmpty { return [] }
        
        let isins = holdingQuantities.map { $0.isin }
        let priceIndex = buildPriceIndex(for: isins)
        
        let earliestPerInstrument = earliestDates(from: priceIndex, isins: isins)
        let effectiveStartDate = earliestPerInstrument.max() ?? cutoffStr
        let actualStartDate = max(cutoffStr, effectiveStartDate)
        
        let sortedDates = collectDates(from: priceIndex, isins: isins, startDate: actualStartDate)
        
        var accountHistory: [(date: Date, value: Double)] = []
        accountHistory.reserveCapacity(sortedDates.count)
        
        for dateStr in sortedDates {
            var totalValueEUR = 0.0
            var allHaveData = true
            
            for holding in holdingQuantities {
                if let priceValue = priceLookup(index: priceIndex[holding.isin] ?? [], onOrBefore: dateStr) {
                    let holdingValue = holding.quantity * priceValue
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
