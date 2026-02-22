import Foundation
import SwiftUI

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
    @Published var refreshResult: RefreshResult?
    
    @Published var selectedPeriod: ReportPeriod = .oneWeek {
        didSet {
            if oldValue != selectedPeriod {
                recomputeDashboardCache()
            }
        }
    }
    
    // MARK: - Cached Dashboard Data
    @Published private(set) var cachedPortfolioHistory: [(date: Date, value: Double)] = []
    @Published private(set) var cachedSP500History: [(date: Date, value: Double)] = []
    @Published private(set) var cachedGoldHistory: [(date: Date, value: Double)] = []
    @Published private(set) var cachedMSCIWorldHistory: [(date: Date, value: Double)] = []
    @Published private(set) var cachedGrandTotalsEUR: (current: Double, previous: Double) = (0, 0)
    @Published private(set) var cachedQuadrantReport: [QuadrantReportItem] = []
    
    // Backfill logs for single instrument
    @Published var backfillLogs: [String] = []
    @Published var showBackfillLogs = false
    
    let db = DatabaseService.shared
    let marketData = MarketDataService.shared
    private let demoMode = DemoModeManager.shared
    private var currencyByIsin: [String: String] = [:]
    private var eurRateCache: [String: Double] = [:]
    
    init() {
        refreshAll()
    }
    
    // MARK: - Demo Mode Helpers
    
    /// Returns the effective quantity for display, applying demo mode randomization if enabled
    /// - Parameters:
    ///   - isin: The instrument ISIN
    ///   - originalQuantity: The original quantity from the database
    ///   - currentPrice: The current price per unit (used to calculate quantity that keeps value < 50,000)
    func effectiveQuantity(forIsin isin: String, originalQuantity: Double, currentPrice: Double?) -> Double {
        return demoMode.getRandomizedQuantity(forIsin: isin, originalQuantity: originalQuantity, currentPrice: currentPrice)
    }
    
    /// Returns the effective total quantity across all accounts, applying demo mode if enabled
    /// - Parameters:
    ///   - isin: The instrument ISIN
    ///   - currentPrice: The current price per unit (used to calculate quantity that keeps value < 50,000)
    func effectiveTotalQuantity(forIsin isin: String, currentPrice: Double?) -> Double {
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
    func convertToEUR(value: Double, fromCurrency: String?, onDate: String) -> Double {
        guard let currency = fromCurrency, currency != "EUR" else { return value }
        
        let cacheKey = "\(currency)|\(onDate)"
        if let cachedRate = eurRateCache[cacheKey] {
            return value * cachedRate
        }
        
        // Try to get rate on or before the specified date
        if let rate = db.getRateOnOrBefore(from: currency, to: "EUR", date: onDate) {
            eurRateCache[cacheKey] = rate.rate
            return value * rate.rate
        }
        
        // Fallback to latest rate if no historical rate
        if let rate = db.getLatestRate(from: currency, to: "EUR") {
            eurRateCache[cacheKey] = rate.rate
            return value * rate.rate
        }
        
        // No conversion available - return original value
        return value
    }
    
    /// Clears the exchange rate cache. Call at the start of each history/report computation.
    func clearRateCache() {
        eurRateCache.removeAll(keepingCapacity: true)
    }
    
    /// Gets the instrument currency for a given ISIN (O(1) dictionary lookup)
    func getInstrumentCurrency(forIsin isin: String) -> String? {
        return currencyByIsin[isin]
    }
    
    // MARK: - Refresh Data
    func refreshAll() {
        instruments = db.getAllInstruments()
        quadrants = db.getAllQuadrants()
        bankAccounts = db.getAllBankAccounts()
        holdings = db.getAllHoldings()
        rebuildCurrencyIndex()
        recomputeDashboardCache()
    }
    
    private func rebuildCurrencyIndex() {
        var dict: [String: String] = [:]
        dict.reserveCapacity(instruments.count)
        for instrument in instruments {
            if let currency = instrument.currency {
                dict[instrument.isin] = currency
            }
        }
        currencyByIsin = dict
    }
    
    /// Recomputes all cached dashboard data. Called after refreshAll(), price updates, and period changes.
    func recomputeDashboardCache() {
        cachedPortfolioHistory = getPortfolioValueHistory()
        cachedSP500History = getSP500ComparisonHistory()
        cachedGoldHistory = getGoldComparisonHistory()
        cachedMSCIWorldHistory = getMSCIWorldComparisonHistory()
        cachedGrandTotalsEUR = getGrandTotalsEUR()
        cachedQuadrantReport = getQuadrantReport()
    }
    
    // MARK: - Targeted Refresh Methods
    func refreshInstruments() {
        instruments = db.getAllInstruments()
        rebuildCurrencyIndex()
    }
    
    func refreshQuadrants() {
        quadrants = db.getAllQuadrants()
    }
    
    func refreshBankAccounts() {
        bankAccounts = db.getAllBankAccounts()
    }
    
    func refreshHoldings() {
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
            refreshInstruments()
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
        refreshInstruments()
        refreshHoldings()
    }
    
    func assignQuadrant(instrumentIsin: String, quadrantId: Int?) {
        db.assignQuadrant(instrumentIsin: instrumentIsin, quadrantId: quadrantId)
        refreshInstruments()
    }
    
    func updateInstrument(_ instrument: Instrument) {
        db.addOrUpdateInstrument(instrument)
        refreshInstruments()
    }
    
    /// Validates the ticker by fetching market data for the given ISIN and optional ticker.
    /// Returns (true, successMessage) if data was found, (false, errorMessage) otherwise.
    func validateTicker(isin: String, ticker: String?) async -> (isValid: Bool, message: String) {
        let result = await marketData.fetchData(isin: isin, ticker: ticker?.isEmpty == true ? nil : ticker)
        if result.value != nil || result.name != nil {
            let name = result.name ?? isin
            return (true, "Valid: \(name)")
        }
        return (false, result.failureReason ?? "No data found for this ticker")
    }
    
    func deletePrice(isin: String, date: String) {
        db.deletePrice(isin: isin, date: date)
        // Prices aren't stored in @Published arrays — no table reload needed
    }
    
    // MARK: - Quadrants
    func addQuadrant(name: String) {
        if db.addQuadrant(name: name) {
            refreshQuadrants()
        } else {
            errorMessage = "Quadrant '\(name)' already exists"
        }
    }
    
    func deleteQuadrant(id: Int) {
        db.deleteQuadrant(id: id)
        refreshQuadrants()
        refreshInstruments() // quadrant assignment may be cleared
    }
    
    // MARK: - Bank Accounts
    func addBankAccount(bank: String, account: String) {
        if db.addBankAccount(bank: bank, account: account) {
            refreshBankAccounts()
        } else {
            errorMessage = "Account '\(bank) - \(account)' already exists"
        }
    }
    
    func deleteBankAccount(id: Int) {
        db.deleteBankAccount(id: id)
        refreshBankAccounts()
        refreshHoldings() // holdings for deleted account are removed
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
        refreshHoldings()
    }
    
    func updateHolding(accountId: Int, isin: String, quantity: Double, purchaseDate: String?, purchasePrice: Double?) {
        db.updateHolding(accountIdValue: accountId, instrumentIsin: isin, quantity: quantity, purchaseDate: purchaseDate, purchasePrice: purchasePrice)
        refreshHoldings()
    }
    
    func deleteHolding(accountId: Int, isin: String) {
        db.deleteHolding(accountIdValue: accountId, instrumentIsin: isin)
        refreshHoldings()
    }
    
    /// Date when the app last refreshed prices (background or manual). Same source as Settings "Last refresh".
    func getLastRefreshDate() -> Date? {
        UserDefaults.standard.object(forKey: "lastBackgroundRefresh") as? Date
    }
    
    /// Date of the most recent price data in the database (fallback when no refresh timestamp exists).
    func getLastInstrumentUpdateDate() -> Date? {
        guard let dateStr = db.getLastInstrumentUpdateDate() else { return nil }
        if let date = AppDateFormatter.yearMonthDay.date(from: dateStr) { return date }
        return AppDateFormatter.yearMonthDayTime.date(from: dateStr)
    }
    
    /// Get current gold spot price in EUR per ounce (from VERACASH:GOLD_SPOT which is per gram)
    func getCurrentGoldOuncePrice() -> Double? {
        if let latestPrice = db.getLatestPrice(forIsin: "VERACASH:GOLD_SPOT") {
            // VERACASH:GOLD_SPOT is price per gram, convert to per ounce (1 troy oz = 31.1034768 g)
            return latestPrice.value * 31.1034768
        }
        return nil
    }
    
    // MARK: - Price History
    func getPriceHistory(forIsin isin: String) -> [Price] {
        return db.getPriceHistory(forIsin: isin)
    }
    
    // MARK: - Dismiss Error
    func dismissError() {
        errorMessage = nil
    }
    
    // MARK: - Dismiss Refresh Result
    func dismissRefreshResult() {
        refreshResult = nil
    }
}
