import Foundation
import SwiftUI

// MARK: - Demo Mode Manager
/// Manages demo mode settings with randomized quantities for portfolio anonymization
class DemoModeManager: ObservableObject {
    static let shared = DemoModeManager()
    
    private let demoModeKey = "demoModeEnabled"
    private let demoSeedKey = "demoModeSeed"
    
    /// Maximum value per instrument in demo mode (in the instrument's currency)
    private let maxValuePerInstrument: Double = 10_000.0
    /// Minimum value per instrument to ensure visible positions
    private let minValuePerInstrument: Double = 1_000.0
    
    @Published var isDemoModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isDemoModeEnabled, forKey: demoModeKey)
            if isDemoModeEnabled && demoSeed == 0 {
                // Generate a new seed when first enabling demo mode
                regenerateSeed()
            }
        }
    }
    
    @Published var demoSeed: UInt64 {
        didSet {
            UserDefaults.standard.set(Int64(bitPattern: demoSeed), forKey: demoSeedKey)
        }
    }
    
    // Cache of randomized quantities keyed by ISIN
    private var cachedQuantities: [String: Double] = [:]
    private var lastSeed: UInt64 = 0
    
    private init() {
        self.isDemoModeEnabled = UserDefaults.standard.bool(forKey: demoModeKey)
        let savedSeed = UserDefaults.standard.integer(forKey: demoSeedKey)
        self.demoSeed = savedSeed != 0 ? UInt64(bitPattern: Int64(savedSeed)) : 0
    }
    
    /// Regenerates the random seed and clears cached quantities
    func regenerateSeed() {
        demoSeed = UInt64.random(in: 1...UInt64.max)
        cachedQuantities.removeAll()
    }
    
    /// Gets a randomized quantity for a given ISIN based on price
    /// The quantity is calculated to ensure total value stays below 50,000
    /// - Parameters:
    ///   - isin: The instrument ISIN
    ///   - originalQuantity: The original quantity (used to check if holding exists)
    ///   - currentPrice: The current price per unit (required to calculate max quantity)
    /// - Returns: A randomized quantity that keeps total value under 50,000
    func getRandomizedQuantity(forIsin isin: String, originalQuantity: Double, currentPrice: Double?) -> Double {
        guard isDemoModeEnabled, originalQuantity > 0 else { return originalQuantity }
        
        // Check if seed changed, clear cache if so
        if lastSeed != demoSeed {
            cachedQuantities.removeAll()
            lastSeed = demoSeed
        }
        
        // Return cached value if available
        if let cached = cachedQuantities[isin] {
            return cached
        }
        
        // Generate a deterministic random factor based on seed and ISIN (0.0 to 1.0)
        var hasher = Hasher()
        hasher.combine(demoSeed)
        hasher.combine(isin)
        let hash = hasher.finalize()
        let randomFactor = abs(Double(hash)) / Double(Int.max)
        
        // Calculate quantity based on price to keep value under maxValuePerInstrument
        let randomQuantity: Double
        if let price = currentPrice, price > 0 {
            // Calculate max quantity that keeps value under limit
            let maxQuantity = maxValuePerInstrument / price
            let minQuantity = minValuePerInstrument / price
            
            // Random value between minQuantity and maxQuantity
            randomQuantity = minQuantity + randomFactor * (maxQuantity - minQuantity)
        } else {
            // Fallback if no price available: use a small fixed range
            randomQuantity = 10.0 + randomFactor * 90.0  // Range: 10 to 100
        }
        
        // Round to 2 decimal places for cleaner display
        let roundedQuantity = (randomQuantity * 100).rounded() / 100
        
        cachedQuantities[isin] = roundedQuantity
        return roundedQuantity
    }
    
    /// Gets the total randomized quantity for an ISIN across all accounts
    func getTotalRandomizedQuantity(forIsin isin: String, originalTotal: Double, currentPrice: Double?) -> Double {
        return getRandomizedQuantity(forIsin: isin, originalQuantity: originalTotal, currentPrice: currentPrice)
    }
}

// MARK: - App View Model
@MainActor
class AppViewModel: ObservableObject {
    @Published var instruments: [Instrument] = []
    @Published var quadrants: [Quadrant] = []
    @Published var bankAccounts: [BankAccount] = []
    @Published var holdings: [Holding] = []
    
    @Published var isLoading = false
    @Published var statusMessage = ""
    @Published var errorMessage: String?
    
    @Published var selectedPeriod: ReportPeriod = .oneWeek
    
    // Backfill logs for single instrument
    @Published var backfillLogs: [String] = []
    @Published var showBackfillLogs = false
    
    private let db = DatabaseService.shared
    private let marketData = MarketDataService.shared
    private let demoMode = DemoModeManager.shared
    
    init() {
        refreshAll()
    }
    
    // MARK: - Demo Mode Helpers
    
    /// Returns the effective quantity for display, applying demo mode randomization if enabled
    /// - Parameters:
    ///   - isin: The instrument ISIN
    ///   - originalQuantity: The original quantity from the database
    ///   - currentPrice: The current price per unit (used to calculate quantity that keeps value < 50,000)
    private func effectiveQuantity(forIsin isin: String, originalQuantity: Double, currentPrice: Double?) -> Double {
        return demoMode.getRandomizedQuantity(forIsin: isin, originalQuantity: originalQuantity, currentPrice: currentPrice)
    }
    
    /// Returns the effective total quantity across all accounts, applying demo mode if enabled
    /// - Parameters:
    ///   - isin: The instrument ISIN
    ///   - currentPrice: The current price per unit (used to calculate quantity that keeps value < 50,000)
    private func effectiveTotalQuantity(forIsin isin: String, currentPrice: Double?) -> Double {
        let originalTotal = db.getTotalQuantity(forIsin: isin)
        return demoMode.getTotalRandomizedQuantity(forIsin: isin, originalTotal: originalTotal, currentPrice: currentPrice)
    }
    
    // MARK: - Currency Conversion
    
    /// Converts a value to EUR using the exchange rate for the given date
    /// - Parameters:
    ///   - value: The value to convert
    ///   - fromCurrency: The source currency (nil or "EUR" means no conversion needed)
    ///   - onDate: The date to use for the exchange rate lookup
    /// - Returns: The value converted to EUR
    private func convertToEUR(value: Double, fromCurrency: String?, onDate: String) -> Double {
        guard let currency = fromCurrency, currency != "EUR" else { return value }
        
        // Try to get rate on or before the specified date
        if let rate = db.getRateOnOrBefore(from: currency, to: "EUR", date: onDate) {
            return value * rate.rate
        }
        
        // Fallback to latest rate if no historical rate
        if let rate = db.getLatestRate(from: currency, to: "EUR") {
            return value * rate.rate
        }
        
        // No conversion available - return original value
        return value
    }
    
    /// Gets the instrument currency for a given ISIN
    private func getInstrumentCurrency(forIsin isin: String) -> String? {
        return instruments.first(where: { $0.isin == isin })?.currency
    }
    
    // MARK: - Refresh Data
    func refreshAll() {
        instruments = db.getAllInstruments()
        quadrants = db.getAllQuadrants()
        bankAccounts = db.getAllBankAccounts()
        holdings = db.getAllHoldings()
    }
    
    // MARK: - Instruments
    func addInstrument(isin: String) async {
        isLoading = true
        statusMessage = "Fetching data for \(isin)..."
        
        let result = await marketData.fetchData(isin: isin)
        
        if result.value != nil || result.name != nil {
            let instrument = Instrument(
                isin: result.isin,
                ticker: result.ticker,
                name: result.name,
                type: "Unknown",
                currency: result.currency,
                quadrantId: nil
            )
            
            db.addOrUpdateInstrument(instrument)
            
            // Save price if available
            if let value = result.value {
                let price = Price(
                    id: nil,
                    isin: result.isin,
                    date: result.date,
                    value: value,
                    currency: result.currency
                )
                db.addPrice(price)
            }
            
            statusMessage = "Added: \(result.name ?? isin)"
            refreshAll()
        } else {
            errorMessage = Self.addInstrumentErrorMessage(for: isin)
            statusMessage = ""
        }
        
        isLoading = false
    }
    
    /// Error message when add instrument finds no data. Clarifies "ISIN:CURRENCY" format (e.g. 12-char ISIN before colon).
    private static func addInstrumentErrorMessage(for isin: String) -> String {
        if let colonIdx = isin.firstIndex(of: ":"), colonIdx > isin.startIndex {
            let prefix = String(isin[..<colonIdx]).trimmingCharacters(in: .whitespaces)
            let suffix = String(isin[isin.index(after: colonIdx)...])
            if prefix.count != 12 {
                return "Could not find data for \(isin). The part before \":\(suffix)\" should be a 12-character ISIN (you have \(prefix.count)). Check for a typo (e.g. missing or extra character)."
            }
        }
        return "Could not find data for ISIN: \(isin)"
    }
    
    func deleteInstrument(_ isin: String) {
        db.deleteInstrument(isin)
        refreshAll()
    }
    
    func assignQuadrant(instrumentIsin: String, quadrantId: Int?) {
        db.assignQuadrant(instrumentIsin: instrumentIsin, quadrantId: quadrantId)
        refreshAll()
    }
    
    // MARK: - Manual Price Management
    func addManualPrice(isin: String, date: String, value: Double, currency: String) {
        let price = Price(id: nil, isin: isin, date: date, value: value, currency: currency)
        db.addPrice(price)
        refreshAll()
    }
    
    func deletePrice(isin: String, date: String) {
        db.deletePrice(isin: isin, date: date)
        refreshAll()
    }
    
    // MARK: - Update Prices
    func updateAllPrices() async {
        isLoading = true
        let total = instruments.count
        
        for (index, instrument) in instruments.enumerated() {
            statusMessage = "Updating \(index + 1)/\(total): \(instrument.displayName)"
            
            let result = await marketData.fetchData(isin: instrument.isin, ticker: instrument.ticker)
            
            if let value = result.value {
                let price = Price(
                    id: nil,
                    isin: instrument.isin,
                    date: result.date,
                    value: value,
                    currency: result.currency
                )
                db.addPrice(price)
            }
            
            // Small delay to be polite to APIs
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        // Update exchange rates
        statusMessage = "Updating exchange rates..."
        if let rate = await marketData.fetchExchangeRate(from: "USD", to: "EUR") {
            db.addExchangeRate(rate)
        }
        
        statusMessage = "Update complete!"
        isLoading = false
        
        // Align with Settings "Last refresh" (same key as iOS BackgroundTaskManager)
        UserDefaults.standard.set(Date(), forKey: "lastBackgroundRefresh")
        
        // Fetch and store S&P 500 history in background (no UI blocking)
        Task { await fetchAndStoreSP500InBackground() }
        
        // Clear status after delay
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        statusMessage = ""
    }
    
    /// Fetches S&P 500 daily history and stores it in the prices table (INDEX:SP500). Called in background after updateAllPrices.
    func fetchAndStoreSP500InBackground() async {
        let prices = await marketData.fetchSP500History(period: "2y", interval: "1d")
        for price in prices {
            db.addPrice(price)
        }
    }
    
    // MARK: - Backfill Historical Data
    func backfillHistorical(period: String = "1y", interval: String = "1mo") async {
        isLoading = true
        let total = instruments.count
        
        for (index, instrument) in instruments.enumerated() {
            statusMessage = "Backfilling \(index + 1)/\(total): \(instrument.displayName)"
            
            let prices = await marketData.fetchHistoricalData(
                isin: instrument.isin,
                ticker: instrument.ticker,
                period: period,
                interval: interval
            )
            
            for price in prices {
                db.addPrice(price)
            }
            
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        // Backfill exchange rates
        statusMessage = "Backfilling exchange rates..."
        let rates = await marketData.fetchHistoricalRates(from: "USD", to: "EUR", period: period, interval: interval)
        for rate in rates {
            db.addExchangeRate(rate)
        }
        
        statusMessage = "Backfill complete!"
        isLoading = false
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        statusMessage = ""
    }
    
    // MARK: - Backfill Single Instrument
    func backfillSingleInstrument(_ instrument: Instrument, period: String = "1y", interval: String = "1mo") async {
        isLoading = true
        backfillLogs = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())
        
        backfillLogs.append("[\(timestamp)] Starting backfill for \(instrument.displayName)")
        backfillLogs.append("[\(timestamp)] ISIN: \(instrument.isin)")
        backfillLogs.append("[\(timestamp)] Ticker: \(instrument.ticker ?? "N/A")")
        backfillLogs.append("[\(timestamp)] Period: \(period), Interval: \(interval)")
        backfillLogs.append("")
        
        statusMessage = "Backfilling: \(instrument.displayName)"
        
        // Build list of tickers to try (primary, then "ISIN:CURRENCY" if applicable, then core ISIN)
        let coreIsin: String = {
            let id = instrument.isin
            if let colon = id.firstIndex(of: ":"), id.distance(from: id.startIndex, to: colon) == 12 {
                let prefix = String(id[..<colon])
                if prefix.allSatisfy({ $0.isLetter || $0.isNumber }) { return prefix }
            }
            return id
        }()
        var tickersToTry: [String] = [instrument.ticker ?? "N/A"].filter { $0 != "N/A" }
        if tickersToTry.isEmpty, coreIsin.count == 12 {
            let resolved = await marketData.resolveIsinToTicker(isin: coreIsin)
            tickersToTry = [resolved ?? coreIsin].filter { $0 != "N/A" }
        }
        if instrument.isin.contains(":"), !tickersToTry.contains(instrument.isin) {
            tickersToTry.append(instrument.isin)
        }
        if coreIsin.count == 12, coreIsin != instrument.isin, !tickersToTry.contains(coreIsin) {
            tickersToTry.append(coreIsin)
        }
        
        var prices: [Price] = []
        for ticker in tickersToTry {
            let ts = dateFormatter.string(from: Date())
            backfillLogs.append("[\(ts)] Trying ticker: \(ticker)")
            let result = await marketData.fetchHistoricalDataForTicker(isin: instrument.isin, ticker: ticker, period: period, interval: interval)
            let ts2 = dateFormatter.string(from: Date())
            if result.isEmpty {
                backfillLogs.append("[\(ts2)]   → No data")
            } else {
                backfillLogs.append("[\(ts2)]   → ✓ \(result.count) price records")
                prices = result
                break
            }
        }
        
        let fetchTimestamp = dateFormatter.string(from: Date())
        if prices.isEmpty {
            backfillLogs.append("")
            backfillLogs.append("[\(fetchTimestamp)] ⚠️ No data returned from Yahoo Finance (tried \(tickersToTry.count) ticker(s))")
            backfillLogs.append("[\(fetchTimestamp)] This may happen if:")
            backfillLogs.append("  • The fund/instrument has no historical chart data on Yahoo Finance")
            backfillLogs.append("  • Yahoo Finance API rate limit was hit")
            backfillLogs.append("")
        } else {
            backfillLogs.append("")
            backfillLogs.append("[\(fetchTimestamp)] ✓ Fetched \(prices.count) price records")
        }
        
        var addedCount = 0
        var skippedCount = 0
        
        for price in prices {
            let existingPrice = db.getPrice(forIsin: instrument.isin, date: price.date)
            if existingPrice == nil {
                db.addPrice(price)
                addedCount += 1
            } else {
                skippedCount += 1
            }
        }
        
        let saveTimestamp = dateFormatter.string(from: Date())
        if addedCount > 0 {
            backfillLogs.append("[\(saveTimestamp)] ✓ Added \(addedCount) new prices")
        } else if !prices.isEmpty {
            backfillLogs.append("[\(saveTimestamp)] No new prices to add (all already exist)")
        }
        if skippedCount > 0 {
            backfillLogs.append("[\(saveTimestamp)] Skipped \(skippedCount) existing prices")
        }
        
        // Backfill exchange rates if instrument is not EUR
        if let currency = instrument.currency, currency != "EUR" {
            backfillLogs.append("")
            backfillLogs.append("[\(saveTimestamp)] Backfilling \(currency)/EUR exchange rates...")
            
            let rates = await marketData.fetchHistoricalRates(from: currency, to: "EUR", period: period, interval: interval)
            
            var ratesAdded = 0
            for rate in rates {
                db.addExchangeRate(rate)
                ratesAdded += 1
            }
            
            let rateTimestamp = dateFormatter.string(from: Date())
            backfillLogs.append("[\(rateTimestamp)] Fetched \(rates.count) exchange rates")
        }
        
        let endTimestamp = dateFormatter.string(from: Date())
        backfillLogs.append("")
        backfillLogs.append("[\(endTimestamp)] Backfill complete!")
        
        statusMessage = ""
        isLoading = false
        showBackfillLogs = true
    }
    
    // MARK: - Quadrants
    func addQuadrant(name: String) {
        if db.addQuadrant(name: name) {
            refreshAll()
        } else {
            errorMessage = "Quadrant '\(name)' already exists"
        }
    }
    
    func deleteQuadrant(id: Int) {
        db.deleteQuadrant(id: id)
        refreshAll()
    }
    
    // MARK: - Bank Accounts
    func addBankAccount(bank: String, account: String) {
        if db.addBankAccount(bank: bank, account: account) {
            refreshAll()
        } else {
            errorMessage = "Account '\(bank) - \(account)' already exists"
        }
    }
    
    func deleteBankAccount(id: Int) {
        db.deleteBankAccount(id: id)
        refreshAll()
    }
    
    // MARK: - Holdings
    func addHolding(accountId: Int, isin: String, quantity: Double, purchaseDate: String?, purchasePrice: Double?) {
        let holding = Holding(
            id: nil,
            accountId: accountId,
            isin: isin,
            quantity: quantity,
            purchaseDate: purchaseDate,
            purchasePrice: purchasePrice,
            lastUpdated: nil
        )
        db.addOrUpdateHolding(holding)
        refreshAll()
    }
    
    func deleteHolding(accountId: Int, isin: String) {
        db.deleteHolding(accountIdValue: accountId, instrumentIsin: isin)
        refreshAll()
    }
    
    // MARK: - Reports
    func getHoldingDetails(forAccount accountId: Int) -> [HoldingDetail] {
        let accountHoldings = holdings.filter { $0.accountId == accountId }
        let comparisonDate = selectedPeriod.comparisonDate
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let comparisonDateStr = formatter.string(from: comparisonDate)
        let todayStr = formatter.string(from: Date())
        
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
        var items: [QuadrantReportItem] = []
        let comparisonDate = selectedPeriod.comparisonDate
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let comparisonDateStr = formatter.string(from: comparisonDate)
        let todayStr = formatter.string(from: Date())
        
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
    
    /// Date when the app last refreshed prices (background or manual). Same source as Settings "Last refresh".
    func getLastRefreshDate() -> Date? {
        UserDefaults.standard.object(forKey: "lastBackgroundRefresh") as? Date
    }
    
    /// Date of the most recent price data in the database (fallback when no refresh timestamp exists).
    func getLastInstrumentUpdateDate() -> Date? {
        guard let dateStr = db.getLastInstrumentUpdateDate() else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateStr) { return date }
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: dateStr)
    }
    
    /// Get current gold spot price in EUR per ounce (from VERACASH:GOLD_SPOT which is per gram)
    func getCurrentGoldOuncePrice() -> Double? {
        if let latestPrice = db.getLatestPrice(forIsin: "VERACASH:GOLD_SPOT") {
            // VERACASH:GOLD_SPOT is price per gram, convert to per ounce (1 troy oz = 31.1034768 g)
            return latestPrice.value * 31.1034768
        }
        return nil
    }
    
    /// Get gold spot price in EUR per ounce at a specific date
    func getGoldOuncePriceOnDate(_ date: Date) -> Double? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        
        if let price = db.getPriceOnOrBefore(forIsin: "VERACASH:GOLD_SPOT", date: dateStr) {
            // VERACASH:GOLD_SPOT is price per gram, convert to per ounce (1 troy oz = 31.1034768 g)
            return price.value * 31.1034768
        }
        return nil
    }
    
    /// Convert EUR value to gold ounces using current spot price
    func convertToGoldOunces(_ eurValue: Double) -> Double? {
        guard let goldOuncePrice = getCurrentGoldOuncePrice(), goldOuncePrice > 0 else {
            return nil
        }
        return eurValue / goldOuncePrice
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
    
    // MARK: - Portfolio History
    func getPortfolioValueHistory() -> [(date: Date, value: Double)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Get cutoff date based on selected period
        let cutoffDate = selectedPeriod.comparisonDate
        let cutoffStr = formatter.string(from: cutoffDate)
        
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
            
            if allHaveData && totalValueEUR > 0, let date = formatter.date(from: dateStr) {
                portfolioHistory.append((date: date, value: totalValueEUR))
            }
        }
        
        return portfolioHistory
    }
    
    /// Get portfolio value history in gold ounces (converts EUR history using gold prices at each date)
    func getGoldOzHistory() -> [(date: Date, value: Double)] {
        let eurHistory = getPortfolioValueHistory()
        if eurHistory.isEmpty { return [] }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        var goldHistory: [(date: Date, value: Double)] = []
        for point in eurHistory {
            let dateStr = formatter.string(from: point.date)
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date0Str = formatter.string(from: date0)
        guard let spAtStart = db.getPriceOnOrBefore(forIsin: SP500IndexIsin, date: date0Str), spAtStart.value > 0 else { return [] }
        
        var result: [(date: Date, value: Double)] = []
        for point in portfolioHistory {
            let dateStr = formatter.string(from: point.date)
            guard let sp = db.getPriceOnOrBefore(forIsin: SP500IndexIsin, date: dateStr), sp.value > 0 else { continue }
            let scaled = value0 * (sp.value / spAtStart.value)
            result.append((date: point.date, value: scaled))
        }
        return result
    }
    
    func getQuadrantValueHistory(quadrantId: Int?) -> [(date: Date, value: Double)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Get cutoff date based on selected period
        let cutoffDate = selectedPeriod.comparisonDate
        let cutoffStr = formatter.string(from: cutoffDate)
        
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
            
            if allHaveData && totalValueEUR > 0, let date = formatter.date(from: dateStr) {
                quadrantHistory.append((date: date, value: totalValueEUR))
            }
        }
        
        return quadrantHistory
    }
    
    /// Convert quadrant value history from EUR to gold ounces using Veracash gold spot price
    func getQuadrantValueHistoryInGold(quadrantId: Int?) -> [(date: Date, value: Double)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
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
            let dateStr = formatter.string(from: point.date)
            
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Get cutoff date based on selected period
        let cutoffDate = selectedPeriod.comparisonDate
        let cutoffStr = formatter.string(from: cutoffDate)
        
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
                if let date = formatter.date(from: price.date) {
                    let holdingValue = effectiveQty * price.value
                    // Always use instrument currency as source of truth
                    let valueInEUR = convertToEUR(value: holdingValue, fromCurrency: instrumentCurrency, onDate: price.date)
                    holdingHistory.append((date: date, value: valueInEUR))
                }
            }
        }
        
        return holdingHistory
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
    
    func getAccountValueHistory(accountId: Int) -> [(date: Date, value: Double)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Get cutoff date based on selected period
        let cutoffDate = selectedPeriod.comparisonDate
        let cutoffStr = formatter.string(from: cutoffDate)
        
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
            
            if allHaveData && totalValueEUR > 0, let date = formatter.date(from: dateStr) {
                accountHistory.append((date: date, value: totalValueEUR))
            }
        }
        
        return accountHistory
    }
    
    // MARK: - Price History
    func getPriceHistory(forIsin isin: String) -> [Price] {
        return db.getPriceHistory(forIsin: isin)
    }
    
    // MARK: - Dismiss Error
    func dismissError() {
        errorMessage = nil
    }
}
