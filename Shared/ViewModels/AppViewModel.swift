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
    @Published private(set) var cachedInvestedCapitalHistory: [(date: Date, value: Double)] = []
    @Published private(set) var cachedTransactionEvents: [PortfolioChartEvent] = []
    @Published private(set) var lastInstrumentUpdateDate: Date? = nil
    @Published private(set) var cachedHoldingDetailsByAccount: [Int: [HoldingDetail]] = [:]
    @Published private(set) var cachedPeriodTWR: Double? = nil
    @Published private(set) var cachedPeriodGainEUR: Double? = nil
    @Published private(set) var cachedHoldingsWithQuantity: [(isin: String, name: String, quantity: Double)] = []
    @Published private(set) var cachedHoldingHistories: [String: [(date: Date, value: Double)]] = [:]
    @Published private(set) var cachedHoldingTWR: [String: Double] = [:]
    @Published private(set) var cachedAccountHistories: [Int: [(date: Date, value: Double)]] = [:]
    @Published private(set) var cachedAccountTWR: [Int: Double] = [:]
    @Published private(set) var cachedQuadrantHistories: [Int: [(date: Date, value: Double)]] = [:]
    @Published private(set) var cachedQuadrantTWR: [Int: Double] = [:]
    @Published private(set) var cachedGoldQuadrantHistories: [Int: [(date: Date, value: Double)]] = [:]
    @Published private(set) var cachedUnassignedHistory: [(date: Date, value: Double)] = []
    @Published private(set) var cachedUnassignedGoldHistory: [(date: Date, value: Double)] = []
    
    // Backfill logs for single instrument
    @Published var backfillLogs: [String] = []
    @Published var showBackfillLogs = false
    
    let db = DatabaseService.shared
    let marketData = MarketDataService.shared
    let demoMode = DemoModeManager.shared
    private var currencyByIsin: [String: String] = [:]
    private var eurRateCache: [String: Double] = [:]
    private static let ledgerMigrationKey = "holdingLedgerMigrationVersion"
    private static let ledgerMigrationVersion = 1
    
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
    func convertToEUR(value: Double, fromCurrency: String?, onDate: String) async -> Double? {
        guard let currency = fromCurrency, currency != "EUR" else { return value }
        
        let cacheKey = "\(currency)|\(onDate)"
        if let cachedRate = eurRateCache[cacheKey] {
            return CurrencyConversion.euros(value: value, fromCurrency: currency, rate: cachedRate)
        }
        
        if let rate = await db.getRateOnOrBefore(from: currency, to: "EUR", date: onDate) {
            eurRateCache[cacheKey] = rate.rate
            return CurrencyConversion.euros(value: value, fromCurrency: currency, rate: rate.rate)
        }
        
        return CurrencyConversion.euros(value: value, fromCurrency: currency, rate: nil)
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
        if UserDefaults.standard.integer(forKey: Self.ledgerMigrationKey) < Self.ledgerMigrationVersion {
            await db.reconcileHoldingTransactions()
            UserDefaults.standard.set(Self.ledgerMigrationVersion, forKey: Self.ledgerMigrationKey)
            holdings = await db.getAllHoldings()
        }
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
        let snapshot = await makeDashboardSnapshot()
        cachedPortfolioHistory = snapshot.portfolio
        cachedInvestedCapitalHistory = snapshot.investedCapital
        cachedSP500History = snapshot.sp500
        cachedGoldHistory = snapshot.gold
        cachedMSCIWorldHistory = snapshot.msciWorld
        cachedGoldOzHistory = snapshot.goldOunces
        cachedTransactionEvents = snapshot.events
        cachedPeriodTWR = snapshot.timeWeightedReturn
        cachedPeriodGainEUR = snapshot.gainEUR
        cachedHoldingDetailsByAccount = await getAllHoldingDetailsByAccount()
        cachedQuadrantReport = getQuadrantReport(from: cachedHoldingDetailsByAccount)
        lastInstrumentUpdateDate = await getLastInstrumentUpdateDate()

        // Header total and chart are both derived from the reconciled transaction ledger.
        cachedGrandTotalsEUR = (
            current: cachedQuadrantReport.reduce(0) { $0 + $1.totalValueEUR },
            previous: cachedQuadrantReport.reduce(0) { $0 + $1.totalPreviousValueEUR }
        )
        if let first = cachedGoldOzHistory.first?.value, let last = cachedGoldOzHistory.last?.value {
            cachedGoldTotals = (current: last, previous: first)
        } else {
            cachedGoldTotals = await getGrandTotalsInGold()
        }

        cachedHoldingsWithQuantity = await getAllHoldingsWithQuantity()
        cachedHoldingHistories = [:]
        cachedHoldingTWR = [:]
        for holding in cachedHoldingsWithQuantity {
            let history = await getHoldingValueHistory(
                isin: holding.isin,
                quantity: holding.quantity
            )
            cachedHoldingHistories[holding.isin] = history
            cachedHoldingTWR[holding.isin] = await getHoldingTWR(isin: holding.isin, history: history)
        }
        cachedAccountHistories = [:]
        cachedAccountTWR = [:]
        for account in bankAccounts {
            let history = await getAccountValueHistory(accountId: account.id)
            cachedAccountHistories[account.id] = history
            cachedAccountTWR[account.id] = await getAccountTWR(accountId: account.id, history: history)
        }
        cachedQuadrantHistories = [:]
        cachedGoldQuadrantHistories = [:]
        cachedQuadrantTWR = [:]
        for quadrant in quadrants {
            let history = await getQuadrantValueHistory(quadrantId: quadrant.id)
            cachedQuadrantHistories[quadrant.id] = history
            cachedQuadrantTWR[quadrant.id] = await getQuadrantTWR(quadrantId: quadrant.id, history: history)
            cachedGoldQuadrantHistories[quadrant.id] = await valueHistoryInGold(history)
        }
        cachedUnassignedHistory = await getQuadrantValueHistory(quadrantId: nil)
        cachedUnassignedGoldHistory = await valueHistoryInGold(cachedUnassignedHistory)

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
        statusMessage = L10n.statusFetchingData(isin)
        
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
            
            statusMessage = L10n.statusAddedInstrument(result.name ?? isin)
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
                return L10n.errorCouldNotFindDataISINLength(isin, suffix, prefix.count)
            }
        }
        return L10n.errorCouldNotFindData(isin)
    }
    
    func deleteInstrument(_ isin: String) async {
        await db.deleteInstrument(isin)
        await refreshInstruments()
        await refreshHoldings()
        await recomputeDashboardCache()
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
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = L10n.errorQuadrantNameRequired
            return
        }

        if await db.addQuadrant(name: trimmedName) {
            await refreshQuadrants()
        } else {
            errorMessage = L10n.errorQuadrantAlreadyExists(trimmedName)
        }
    }
    
    func deleteQuadrant(id: Int) async {
        await db.deleteQuadrant(id: id)
        await refreshQuadrants()
        await refreshInstruments()
    }
    
    // MARK: - Bank Accounts
    func addBankAccount(bank: String, account: String) async {
        let trimmedBank = bank.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedBank.isEmpty, !trimmedAccount.isEmpty else {
            errorMessage = L10n.errorBankAccountNamesRequired
            return
        }

        if await db.addBankAccount(bank: trimmedBank, account: trimmedAccount) {
            await refreshBankAccounts()
        } else {
            errorMessage = L10n.errorAccountAlreadyExists(trimmedBank, trimmedAccount)
        }
    }
    
    func deleteBankAccount(id: Int) async {
        await db.deleteBankAccount(id: id)
        await refreshBankAccounts()
        await refreshHoldings()
        await recomputeDashboardCache()
    }
    
    // MARK: - Holdings
    func addHolding(accountId: Int, isin: String, quantity: Double, purchaseDate: String?, purchasePrice: Double?) async {
        if holdings.contains(where: { $0.accountId == accountId && $0.isin == isin }) {
            await updateHolding(accountId: accountId, isin: isin, quantity: quantity, purchaseDate: purchaseDate, purchasePrice: purchasePrice)
            return
        }
        await recordBuy(
            accountId: accountId,
            isin: isin,
            quantity: quantity,
            date: purchaseDate ?? AppDateFormatter.todayString,
            unitPrice: purchasePrice
        )
    }
    
    func updateHolding(accountId: Int, isin: String, quantity: Double, purchaseDate: String?, purchasePrice: Double?) async {
        let previousQty = holdings.first { $0.accountId == accountId && $0.isin == isin }?.quantity ?? 0
        let delta = quantity - previousQty
        if abs(delta) > 1e-12 {
            await recordAdjustment(
                accountId: accountId,
                isin: isin,
                quantityDelta: delta,
                date: AppDateFormatter.todayString,
                unitPrice: purchasePrice,
                note: nil
            )
        } else {
            await db.updateHolding(
                accountIdValue: accountId,
                instrumentIsin: isin,
                quantity: quantity,
                purchaseDate: purchaseDate,
                purchasePrice: purchasePrice
            )
            await refreshHoldings()
        }
    }
    
    /// Closes a position today while retaining its complete ledger and chart history.
    func deleteHolding(accountId: Int, isin: String) async {
        let remaining = holdings.first { $0.accountId == accountId && $0.isin == isin }?.quantity ?? 0
        if remaining > 0 {
            await recordSell(
                accountId: accountId,
                isin: isin,
                quantity: remaining,
                date: AppDateFormatter.todayString,
                unitPrice: nil
            )
        } else {
            await db.deleteHolding(accountIdValue: accountId, instrumentIsin: isin)
            await refreshHoldings()
            await recomputeDashboardCache()
        }
    }

    /// Permanently deletes both the live cache and every operation for a position.
    func deleteHoldingWithHistory(accountId: Int, isin: String) async {
        await db.deleteHoldingTransactions(accountId: accountId, isin: isin)
        await db.deleteHolding(accountIdValue: accountId, instrumentIsin: isin)
        await refreshHoldings()
        await recomputeDashboardCache()
    }

    func recordBuy(
        accountId: Int,
        isin: String,
        quantity: Double,
        date: String,
        unitPrice: Double?,
        fees: Double? = nil,
        note: String? = nil
    ) async {
        await recordOperation(
            accountId: accountId,
            isin: isin,
            kind: .buy,
            quantity: quantity,
            date: date,
            unitPrice: unitPrice,
            fees: fees,
            note: note
        )
    }

    func recordSell(
        accountId: Int,
        isin: String,
        quantity: Double,
        date: String,
        unitPrice: Double?,
        fees: Double? = nil,
        note: String? = nil
    ) async {
        await recordOperation(
            accountId: accountId,
            isin: isin,
            kind: .sell,
            quantity: quantity,
            date: date,
            unitPrice: unitPrice,
            fees: fees,
            note: note
        )
    }

    func recordAdjustment(
        accountId: Int,
        isin: String,
        quantityDelta: Double,
        date: String,
        unitPrice: Double?,
        note: String?
    ) async {
        guard abs(quantityDelta) > HoldingLedger.epsilon else { return }
        await recordOperation(
            accountId: accountId,
            isin: isin,
            kind: .adjustment,
            quantity: abs(quantityDelta),
            date: date,
            unitPrice: unitPrice,
            note: note,
            signedDelta: quantityDelta
        )
    }

    private func recordOperation(
        accountId: Int,
        isin: String,
        kind: HoldingTransactionKind,
        quantity: Double,
        date: String,
        unitPrice: Double?,
        fees: Double? = nil,
        note: String? = nil,
        signedDelta: Double? = nil
    ) async {
        let existing = await db.getHoldingTransactions(accountId: accountId, isin: isin)
        do {
            try HoldingLedger.validate(
                kind: (signedDelta ?? 1) < 0 ? .sell : kind,
                quantity: quantity,
                date: date,
                today: AppDateFormatter.todayString,
                existing: existing
            )
        } catch {
            errorMessage = ledgerValidationMessage(error)
            return
        }

        await db.addHoldingTransaction(
            accountId: accountId,
            isin: isin,
            date: date,
            quantityDelta: signedDelta ?? HoldingLedger.signedQuantity(kind: kind, quantity: quantity),
            unitPrice: unitPrice,
            kind: kind,
            fees: fees,
            note: note
        )
        await db.synchronizeHoldingFromTransactions(accountId: accountId, isin: isin)
        await refreshHoldings()
        await backfillHistoryIfNeeded(isin: isin, oldestDate: min(date, existing.first?.date ?? date))
        await recomputeDashboardCache()
    }

    func updateTransaction(_ transaction: HoldingTransaction) async {
        guard let id = transaction.id else { return }
        let existing = await db.getHoldingTransactions(accountId: transaction.accountId, isin: transaction.isin)
        do {
            try HoldingLedger.validate(
                kind: transaction.quantityDelta < 0 ? .sell : transaction.kind,
                quantity: abs(transaction.quantityDelta),
                date: transaction.date,
                today: AppDateFormatter.todayString,
                existing: existing,
                excludingID: id
            )
            var candidate = existing.filter { $0.id != id }
            candidate.append(transaction)
            try HoldingLedger.validateSequence(candidate)
        } catch {
            errorMessage = ledgerValidationMessage(error)
            return
        }
        await db.updateHoldingTransaction(transaction)
        await db.synchronizeHoldingFromTransactions(accountId: transaction.accountId, isin: transaction.isin)
        await refreshHoldings()
        let oldestDate = existing.filter { $0.id != id }.map(\.date).min().map {
            min($0, transaction.date)
        } ?? transaction.date
        await backfillHistoryIfNeeded(isin: transaction.isin, oldestDate: oldestDate)
        await recomputeDashboardCache()
    }

    func deleteTransaction(_ transaction: HoldingTransaction) async {
        guard let id = transaction.id else { return }
        let existing = await db.getHoldingTransactions(accountId: transaction.accountId, isin: transaction.isin)
        do {
            try HoldingLedger.validateSequence(existing.filter { $0.id != id })
        } catch {
            errorMessage = ledgerValidationMessage(error)
            return
        }
        await db.deleteHoldingTransaction(id: id)
        await db.synchronizeHoldingFromTransactions(accountId: transaction.accountId, isin: transaction.isin)
        await refreshHoldings()
        await recomputeDashboardCache()
    }

    private func ledgerValidationMessage(_ error: Error) -> String {
        switch error {
        case HoldingLedgerValidationError.invalidQuantity:
            return L10n.ledgerInvalidQuantity
        case HoldingLedgerValidationError.futureDate:
            return L10n.ledgerFutureDate
        case HoldingLedgerValidationError.insufficientQuantity(let available):
            return L10n.ledgerInsufficientQuantity(available)
        default:
            return L10n.ledgerInvalidOperation
        }
    }

    private func backfillHistoryIfNeeded(isin: String, oldestDate: String) async {
        guard let instrument = await db.getInstrument(byIsin: isin) else { return }
        let parameters = HoldingLedger.backfillParameters(oldestDate: oldestDate)
        await backfillSingleInstrument(
            instrument,
            period: parameters.period,
            interval: parameters.interval,
            silent: true
        )
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
    
    // MARK: - Preview Support
    
    /// A pre-populated view model for SwiftUI previews (does not touch the database).
    static var preview: AppViewModel {
        let vm = AppViewModel(forPreview: true)
        
        let today = Date()
        let calendar = Calendar.current
        
        // Mock instruments
        vm.instruments = [
            Instrument(isin: "FR0010315770", ticker: "EWLD.PA", name: "Lyxor MSCI World", currency: "EUR", quadrantId: 1),
            Instrument(isin: "LU1681043599", ticker: "PANX.PA", name: "Amundi Nasdaq-100", currency: "EUR", quadrantId: 1),
            Instrument(isin: "FR0011550185", ticker: "ESE.PA", name: "BNP S&P 500", currency: "EUR", quadrantId: 2),
            Instrument(isin: "IE00B4L5Y983", ticker: "IWDA.AS", name: "iShares Core MSCI World", currency: "USD", quadrantId: 2),
        ]
        
        // Mock quadrants
        vm.quadrants = [
            Quadrant(id: 1, name: "Growth"),
            Quadrant(id: 2, name: "Core"),
        ]
        
        // Mock bank accounts
        vm.bankAccounts = [
            BankAccount(id: 1, bankName: "BoursoBank", accountName: "PEA"),
            BankAccount(id: 2, bankName: "Fortuneo", accountName: "CTO"),
        ]
        
        // Mock holdings
        vm.holdings = [
            Holding(id: 1, accountId: 1, isin: "FR0010315770", quantity: 50, purchaseDate: "2024-01-15", purchasePrice: 24.50, lastUpdated: nil),
            Holding(id: 2, accountId: 1, isin: "LU1681043599", quantity: 30, purchaseDate: "2024-03-10", purchasePrice: 72.30, lastUpdated: nil),
            Holding(id: 3, accountId: 2, isin: "FR0011550185", quantity: 100, purchaseDate: "2023-06-01", purchasePrice: 18.90, lastUpdated: nil),
            Holding(id: 4, accountId: 2, isin: "IE00B4L5Y983", quantity: 20, purchaseDate: "2024-06-20", purchasePrice: 82.00, lastUpdated: nil),
        ]
        
        // Mock cached dashboard data — generate 30-day history
        var portfolioHistory: [(date: Date, value: Double)] = []
        var sp500History: [(date: Date, value: Double)] = []
        var goldHistory: [(date: Date, value: Double)] = []
        var msciHistory: [(date: Date, value: Double)] = []
        var goldOzHistory: [(date: Date, value: Double)] = []
        
        let basePortfolioValue: Double = 12_500
        let baseSP500Value: Double = 12_500
        let baseGoldValue: Double = 12_500
        let baseMSCIValue: Double = 12_500
        let baseGoldOz: Double = 4.8
        
        for i in (0..<30).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let progress = Double(30 - i) / 30.0
            portfolioHistory.append((date: date, value: basePortfolioValue * (1 + progress * 0.08 + Double.random(in: -0.01...0.01))))
            sp500History.append((date: date, value: baseSP500Value * (1 + progress * 0.06 + Double.random(in: -0.01...0.01))))
            goldHistory.append((date: date, value: baseGoldValue * (1 + progress * 0.03 + Double.random(in: -0.005...0.005))))
            msciHistory.append((date: date, value: baseMSCIValue * (1 + progress * 0.07 + Double.random(in: -0.01...0.01))))
            goldOzHistory.append((date: date, value: baseGoldOz * (1 + progress * 0.05 + Double.random(in: -0.005...0.005))))
        }
        
        vm.cachedPortfolioHistory = portfolioHistory
        vm.cachedSP500History = sp500History
        vm.cachedGoldHistory = goldHistory
        vm.cachedMSCIWorldHistory = msciHistory
        vm.cachedGoldOzHistory = goldOzHistory
        vm.cachedGrandTotalsEUR = (current: 13_500, previous: 12_500)
        vm.cachedGoldTotals = (current: 5.04, previous: 4.80)
        vm.cachedPeriodTWR = 8.0
        vm.lastInstrumentUpdateDate = today
        
        // Mock quadrant report
        let mockHoldings1 = [
            HoldingDetail(accountId: 1, isin: "FR0010315770", instrumentName: "Lyxor MSCI World", instrumentCurrency: "EUR", ticker: "EWLD.PA", quantity: 50, currentPrice: 27.40, previousPrice: 25.80, priceDate: "2026-03-22", currentValueEUR: 1370, previousValueEUR: 1290),
            HoldingDetail(accountId: 1, isin: "LU1681043599", instrumentName: "Amundi Nasdaq-100", instrumentCurrency: "EUR", ticker: "PANX.PA", quantity: 30, currentPrice: 85.10, previousPrice: 78.50, priceDate: "2026-03-22", currentValueEUR: 2553, previousValueEUR: 2355),
        ]
        let mockHoldings2 = [
            HoldingDetail(accountId: 2, isin: "FR0011550185", instrumentName: "BNP S&P 500", instrumentCurrency: "EUR", ticker: "ESE.PA", quantity: 100, currentPrice: 21.30, previousPrice: 20.10, priceDate: "2026-03-22", currentValueEUR: 2130, previousValueEUR: 2010),
            HoldingDetail(accountId: 2, isin: "IE00B4L5Y983", instrumentName: "iShares Core MSCI World", instrumentCurrency: "USD", ticker: "IWDA.AS", quantity: 20, currentPrice: 89.50, previousPrice: 85.00, priceDate: "2026-03-22", currentValueEUR: 1648, previousValueEUR: 1565),
        ]
        vm.cachedQuadrantReport = [
            QuadrantReportItem(quadrant: Quadrant(id: 1, name: "Growth"), holdings: mockHoldings1),
            QuadrantReportItem(quadrant: Quadrant(id: 2, name: "Core"), holdings: mockHoldings2),
        ]
        
        // Mock holding details by account
        vm.cachedHoldingDetailsByAccount = [
            1: mockHoldings1,
            2: mockHoldings2,
        ]
        
        return vm
    }
    
    /// Private initializer for previews — skips database refresh.
    private init(forPreview: Bool) {
        // No-op: the static `preview` property populates all @Published properties directly.
    }
}
