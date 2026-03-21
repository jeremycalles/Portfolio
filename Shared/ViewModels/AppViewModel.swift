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
                Task { @MainActor in await self.recomputeDashboardCache() }
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
    @Published private(set) var cachedGoldTotals: (current: Double, previous: Double)? = nil
    @Published private(set) var cachedGoldOzHistory: [(date: Date, value: Double)] = []
    @Published private(set) var lastInstrumentUpdateDate: Date? = nil
    @Published private(set) var cachedHoldingDetailsByAccount: [Int: [HoldingDetail]] = [:]
    
    // Backfill logs for single instrument
    @Published var backfillLogs: [String] = []
    @Published var showBackfillLogs = false
    
    let db = DatabaseService.shared
    let marketData = MarketDataService.shared
    private let demoMode = DemoModeManager.shared
    private var currencyByIsin: [String: String] = [:]
    private var eurRateCache: [String: Double] = [:]
    
    init() {
        Task { await refreshAll() }
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
    func effectiveTotalQuantity(forIsin isin: String, currentPrice: Double?) async -> Double {
        let originalTotal = await db.getTotalQuantity(forIsin: isin)
        return demoMode.getTotalRandomizedQuantity(forIsin: isin, originalTotal: originalTotal, currentPrice: currentPrice)
    }
    
    // MARK: - Currency Conversion
    
    /// Converts a value to EUR using the exchange rate for the given date
    /// - Parameters:
    ///   - value: The value to convert
    ///   - fromCurrency: The source currency (nil or "EUR" means no conversion needed)
    ///   - onDate: The date to use for the exchange rate lookup
    /// - Returns: The value converted to EUR
    func convertToEUR(value: Double, fromCurrency: String?, onDate: String) async -> Double {
        guard let currency = fromCurrency, currency != "EUR" else { return value }
        
        let cacheKey = "\(currency)|\(onDate)"
        if let cachedRate = eurRateCache[cacheKey] {
            return value * cachedRate
        }
        
        if let rate = await db.getRateOnOrBefore(from: currency, to: "EUR", date: onDate) {
            eurRateCache[cacheKey] = rate.rate
            return value * rate.rate
        }
        
        if let rate = await db.getLatestRate(from: currency, to: "EUR") {
            eurRateCache[cacheKey] = rate.rate
            return value * rate.rate
        }
        
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
    func refreshAll() async {
        instruments = await db.getAllInstruments()
        quadrants = await db.getAllQuadrants()
        bankAccounts = await db.getAllBankAccounts()
        holdings = await db.getAllHoldings()
        rebuildCurrencyIndex()
        await recomputeDashboardCache()
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
    func recomputeDashboardCache() async {
        cachedPortfolioHistory = await getPortfolioValueHistory()
        cachedSP500History = await getSP500ComparisonHistory()
        cachedGoldHistory = await getGoldComparisonHistory()
        cachedMSCIWorldHistory = await getMSCIWorldComparisonHistory()
        cachedGrandTotalsEUR = await getGrandTotalsEUR()
        cachedQuadrantReport = await getQuadrantReport()
        cachedGoldTotals = await getGrandTotalsInGold()
        cachedGoldOzHistory = await getGoldOzHistory()
        lastInstrumentUpdateDate = await getLastInstrumentUpdateDate()
        var detailsByAccount: [Int: [HoldingDetail]] = [:]
        for account in bankAccounts {
            detailsByAccount[account.id] = await getHoldingDetails(forAccount: account.id)
        }
        cachedHoldingDetailsByAccount = detailsByAccount
    }
    
    // MARK: - Targeted Refresh Methods
    func refreshInstruments() async {
        instruments = await db.getAllInstruments()
        rebuildCurrencyIndex()
    }
    
    func refreshQuadrants() async {
        quadrants = await db.getAllQuadrants()
    }
    
    func refreshBankAccounts() async {
        bankAccounts = await db.getAllBankAccounts()
    }
    
    func refreshHoldings() async {
        holdings = await db.getAllHoldings()
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
            
            await db.addOrUpdateInstrument(instrument)
            
            if let value = result.value {
                let price = Price(
                    id: nil,
                    isin: result.isin,
                    date: result.date,
                    value: value,
                    currency: result.currency
                )
                await db.addPrice(price)
            }
            
            statusMessage = "Added: \(result.name ?? isin)"
            await refreshInstruments()
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
    
    func deleteInstrument(_ isin: String) async {
        await db.deleteInstrument(isin)
        await refreshInstruments()
        await refreshHoldings()
    }
    
    func assignQuadrant(instrumentIsin: String, quadrantId: Int?) async {
        await db.assignQuadrant(instrumentIsin: instrumentIsin, quadrantId: quadrantId)
        await refreshInstruments()
    }
    
    func updateInstrument(_ instrument: Instrument) async {
        await db.addOrUpdateInstrument(instrument)
        await refreshInstruments()
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
    
    func deletePrice(isin: String, date: String) async {
        await db.deletePrice(isin: isin, date: date)
    }
    
    // MARK: - Quadrants
    func addQuadrant(name: String) async {
        if await db.addQuadrant(name: name) {
            await refreshQuadrants()
        } else {
            errorMessage = "Quadrant '\(name)' already exists"
        }
    }
    
    func deleteQuadrant(id: Int) async {
        await db.deleteQuadrant(id: id)
        await refreshQuadrants()
        await refreshInstruments()
    }
    
    // MARK: - Bank Accounts
    func addBankAccount(bank: String, account: String) async {
        if await db.addBankAccount(bank: bank, account: account) {
            await refreshBankAccounts()
        } else {
            errorMessage = "Account '\(bank) - \(account)' already exists"
        }
    }
    
    func deleteBankAccount(id: Int) async {
        await db.deleteBankAccount(id: id)
        await refreshBankAccounts()
        await refreshHoldings()
    }
    
    // MARK: - Holdings
    func addHolding(accountId: Int, isin: String, quantity: Double, purchaseDate: String?, purchasePrice: Double?) async {
        let holding = Holding(
            id: nil,
            accountId: accountId,
            isin: isin,
            quantity: quantity,
            purchaseDate: purchaseDate,
            purchasePrice: purchasePrice,
            lastUpdated: nil
        )
        await db.addOrUpdateHolding(holding)
        await refreshHoldings()
        if let instrument = await db.getInstrument(byIsin: isin) {
            Task {
                await backfillSingleInstrument(instrument, period: "1mo", interval: "1d", silent: true)
            }
        }
    }
    
    func updateHolding(accountId: Int, isin: String, quantity: Double, purchaseDate: String?, purchasePrice: Double?) async {
        await db.updateHolding(accountIdValue: accountId, instrumentIsin: isin, quantity: quantity, purchaseDate: purchaseDate, purchasePrice: purchasePrice)
        await refreshHoldings()
    }
    
    func deleteHolding(accountId: Int, isin: String) async {
        await db.deleteHolding(accountIdValue: accountId, instrumentIsin: isin)
        await refreshHoldings()
    }
    
    /// Date when the app last refreshed prices (background or manual). Same source as Settings "Last refresh".
    func getLastRefreshDate() -> Date? {
        UserDefaults.standard.object(forKey: "lastBackgroundRefresh") as? Date
    }
    
    /// Date of the most recent price data in the database (fallback when no refresh timestamp exists).
    func getLastInstrumentUpdateDate() async -> Date? {
        guard let dateStr = await db.getLastInstrumentUpdateDate() else { return nil }
        if let date = AppDateFormatter.yearMonthDay.date(from: dateStr) { return date }
        return AppDateFormatter.yearMonthDayTime.date(from: dateStr)
    }
    
    /// Get current gold spot price in EUR per ounce (from VERACASH:GOLD_SPOT which is per gram)
    func getCurrentGoldOuncePrice() async -> Double? {
        if let latestPrice = await db.getLatestPrice(forIsin: "VERACASH:GOLD_SPOT") {
            return latestPrice.value * 31.1034768
        }
        return nil
    }
    
    // MARK: - Price History
    func getPriceHistory(forIsin isin: String) async -> [Price] {
        return await db.getPriceHistory(forIsin: isin)
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
