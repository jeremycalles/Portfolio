import Foundation

/// Shared price refresh logic used by both iOS BackgroundTaskManager and macOS MacOSSchedulerManager
@MainActor
final class PriceRefreshService {
    static let shared = PriceRefreshService()
    
    private init() {}
    
    /// Performs a price refresh for all instruments
    /// - Parameter logHandler: Optional closure to handle log messages (isError indicates error status)
    /// - Returns: Tuple of (successCount, failureCount)
    func refreshAllPrices(logHandler: ((String, Bool) -> Void)? = nil) async -> (success: Int, failure: Int) {
        var successCount = 0
        var failureCount = 0
        
        let instruments = DatabaseService.shared.getAllInstruments()
        
        guard !instruments.isEmpty else {
            logHandler?("No instruments to refresh", false)
            return (0, 0)
        }
        
        logHandler?("Found \(instruments.count) instruments to refresh", false)
        
        // Update prices for all instruments
        for instrument in instruments {
            let displayName = instrument.name ?? instrument.ticker ?? instrument.isin
            
            let result = await MarketDataService.shared.fetchData(isin: instrument.isin, ticker: instrument.ticker)
            
            if let price = result.value {
                let newPrice = Price(
                    isin: instrument.isin,
                    date: result.date,
                    value: price,
                    currency: result.currency
                )
                DatabaseService.shared.addPrice(newPrice)
                
                // Update instrument info if available (but NOT currency - that should stay as originally set)
                if result.name != nil || result.ticker != nil {
                    var updatedInstrument = instrument
                    if let name = result.name { updatedInstrument.name = name }
                    if let ticker = result.ticker { updatedInstrument.ticker = ticker }
                    // Do NOT update currency here - FT may return wrong share class currency
                    DatabaseService.shared.addOrUpdateInstrument(updatedInstrument)
                }
                
                logHandler?("\(displayName): \(String(format: "%.2f", price)) \(result.currency ?? "")", false)
                successCount += 1
            } else {
                let reason = result.failureReason ?? "Failed to fetch price"
                logHandler?("\(displayName): \(reason)", true)
                failureCount += 1
            }
            
            // Small delay to avoid rate limiting
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        // Save last refresh time
        UserDefaults.standard.set(Date(), forKey: "lastBackgroundRefresh")
        
        return (successCount, failureCount)
    }
    
    /// Fetches and stores benchmark data (S&P 500, Gold, MSCI World)
    /// - Parameter logHandler: Optional closure to handle log messages
    func fetchBenchmarks(logHandler: ((String, Bool) -> Void)? = nil) async {
        logHandler?("Fetching benchmark data...", false)
        
        async let sp500Prices = MarketDataService.shared.fetchSP500History(period: "2y", interval: "1d")
        async let goldPrices = MarketDataService.shared.fetchGoldHistory(period: "2y", interval: "1d")
        async let msciPrices = MarketDataService.shared.fetchMSCIWorldHistory(period: "2y", interval: "1d")
        
        let (sp500Result, goldResult, msciResult) = await (sp500Prices, goldPrices, msciPrices)
        
        for price in sp500Result { DatabaseService.shared.addPrice(price) }
        for price in goldResult { DatabaseService.shared.addPrice(price) }
        for price in msciResult { DatabaseService.shared.addPrice(price) }
        
        logHandler?("Benchmarks updated (S&P500: \(sp500Result.count), Gold: \(goldResult.count), MSCI: \(msciResult.count))", false)
    }
    
    /// Updates exchange rates
    /// - Parameter logHandler: Optional closure to handle log messages
    func updateExchangeRates(logHandler: ((String, Bool) -> Void)? = nil) async {
        logHandler?("Updating exchange rates...", false)
        if let rate = await MarketDataService.shared.fetchExchangeRate(from: "USD", to: "EUR") {
            DatabaseService.shared.addExchangeRate(rate)
            logHandler?("USD/EUR rate updated", false)
        }
    }
}

// MARK: - Shared Time Since Last Refresh Helper
extension PriceRefreshService {
    /// Returns a formatted string describing the time since the last refresh
    var timeSinceLastRefresh: String {
        guard let lastRefresh = UserDefaults.standard.object(forKey: "lastBackgroundRefresh") as? Date else {
            return "Never"
        }
        
        let interval = Date().timeIntervalSince(lastRefresh)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) min ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
    
    /// Returns whether a refresh is needed based on the minimum interval
    /// - Parameter minimumInterval: The minimum time between refreshes in seconds
    /// - Returns: True if refresh is needed
    func needsRefresh(minimumInterval: TimeInterval) -> Bool {
        guard let lastRefresh = UserDefaults.standard.object(forKey: "lastBackgroundRefresh") as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastRefresh) > minimumInterval
    }
}
