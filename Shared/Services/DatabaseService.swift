import Foundation

#if canImport(SQLite)
import SQLite
#endif

#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

// MARK: - Storage Log Entry
struct StorageLogEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let message: String
    let isWarning: Bool
    let isError: Bool
    
    init(message: String, isWarning: Bool = false, isError: Bool = false) {
        self.id = UUID()
        self.timestamp = Date()
        self.message = message
        self.isWarning = isWarning
        self.isError = isError
    }
}

#if canImport(SQLite)
// MARK: - Database Actor (runs all SQLite I/O off the main thread)
private actor DatabaseActor {
    private let dbPath: String
    private var connection: Connection?
    
    init(path: String) {
        self.dbPath = path
    }
    
    private func ensureConnected() throws {
        if connection == nil {
            connection = try Connection(dbPath)
            try initializeDatabase()
        }
    }
    
    private let instruments = Table("instruments")
    private let prices = Table("prices")
    private let exchangeRates = Table("exchange_rates")
    private let quadrants = Table("quadrants")
    private let bankAccounts = Table("bank_accounts")
    private let holdings = Table("holdings")
    
    private let isin = SQLite.Expression<String>("isin")
    private let ticker = SQLite.Expression<String?>("ticker")
    private let name = SQLite.Expression<String?>("name")
    private let currency = SQLite.Expression<String?>("currency")
    private let quadrantId = SQLite.Expression<Int?>("quadrant_id")
    private let priceId = SQLite.Expression<Int>("id")
    private let priceIsin = SQLite.Expression<String>("isin")
    private let date = SQLite.Expression<String>("date")
    private let value = SQLite.Expression<Double>("value")
    private let priceCurrency = SQLite.Expression<String?>("currency")
    private let rateId = SQLite.Expression<Int>("id")
    private let rateDate = SQLite.Expression<String>("date")
    private let fromCurrency = SQLite.Expression<String>("from_currency")
    private let toCurrency = SQLite.Expression<String>("to_currency")
    private let rate = SQLite.Expression<Double>("rate")
    private let quadId = SQLite.Expression<Int>("id")
    private let quadName = SQLite.Expression<String>("name")
    private let accountId = SQLite.Expression<Int>("id")
    private let bankName = SQLite.Expression<String>("bank_name")
    private let accountName = SQLite.Expression<String>("account_name")
    private let holdingId = SQLite.Expression<Int>("id")
    private let holdingAccountId = SQLite.Expression<Int>("account_id")
    private let holdingIsin = SQLite.Expression<String>("isin")
    private let quantity = SQLite.Expression<Double>("quantity")
    private let purchaseDate = SQLite.Expression<String?>("purchase_date")
    private let purchasePrice = SQLite.Expression<Double?>("purchase_price")
    private let lastUpdated = SQLite.Expression<String?>("last_updated")
    
    private func instrumentFromRow(_ row: Row) -> Instrument {
        Instrument(isin: row[isin], ticker: row[ticker], name: row[name], currency: row[currency], quadrantId: row[quadrantId])
    }
    private func priceFromRow(_ row: Row) -> Price {
        Price(id: row[priceId], isin: row[priceIsin], date: row[date], value: row[value], currency: row[priceCurrency])
    }
    private func exchangeRateFromRow(_ row: Row) -> ExchangeRate {
        ExchangeRate(id: row[rateId], date: row[rateDate], fromCurrency: row[fromCurrency], toCurrency: row[toCurrency], rate: row[rate])
    }
    private func quadrantFromRow(_ row: Row) -> Quadrant {
        Quadrant(id: row[quadId], name: row[quadName])
    }
    private func bankAccountFromRow(_ row: Row) -> BankAccount {
        BankAccount(id: row[accountId], bankName: row[bankName], accountName: row[accountName])
    }
    private func holdingFromRow(_ row: Row) -> Holding {
        Holding(id: row[holdingId], accountId: row[holdingAccountId], isin: row[holdingIsin], quantity: row[quantity], purchaseDate: row[purchaseDate], purchasePrice: row[purchasePrice], lastUpdated: row[lastUpdated])
    }
    
    private func fetchAll<T>(query: QueryType, mapper: (Row) -> T) throws -> [T] {
        guard let db = connection else { return [] }
        var result: [T] = []
        for row in try db.prepare(query) {
            result.append(mapper(row))
        }
        return result
    }
    
    private func initializeDatabase() throws {
        guard let db = connection else { return }
        try db.run(instruments.create(ifNotExists: true) { t in
            t.column(isin, primaryKey: true)
            t.column(ticker)
            t.column(name)
            t.column(currency)
            t.column(quadrantId)
        })
        try db.run(prices.create(ifNotExists: true) { t in
            t.column(priceId, primaryKey: .autoincrement)
            t.column(priceIsin)
            t.column(date)
            t.column(value)
            t.column(priceCurrency)
        })
        try db.run(exchangeRates.create(ifNotExists: true) { t in
            t.column(rateId, primaryKey: .autoincrement)
            t.column(rateDate)
            t.column(fromCurrency)
            t.column(toCurrency)
            t.column(rate)
        })
        try db.run(quadrants.create(ifNotExists: true) { t in
            t.column(quadId, primaryKey: .autoincrement)
            t.column(quadName, unique: true)
        })
        try db.run(bankAccounts.create(ifNotExists: true) { t in
            t.column(accountId, primaryKey: .autoincrement)
            t.column(bankName)
            t.column(accountName)
        })
        try db.run(holdings.create(ifNotExists: true) { t in
            t.column(holdingId, primaryKey: .autoincrement)
            t.column(holdingAccountId)
            t.column(holdingIsin)
            t.column(quantity)
            t.column(purchaseDate)
            t.column(purchasePrice)
            t.column(lastUpdated)
        })
        try db.run(prices.createIndex(priceIsin, date, ifNotExists: true))
        try db.run(exchangeRates.createIndex(fromCurrency, toCurrency, rateDate, ifNotExists: true))
        try db.run(holdings.createIndex(holdingIsin, ifNotExists: true))
        try db.run(holdings.createIndex(holdingAccountId, ifNotExists: true))
    }
    
    func closeConnection() {
        connection = nil
    }
    
    func reconnect() throws {
        connection = nil
        try ensureConnected()
    }
    
    func getAllInstruments() throws -> [Instrument] {
        try ensureConnected()
        return try fetchAll(query: instruments, mapper: instrumentFromRow)
    }
    
    func getInstrument(byIsin instrumentIsin: String) throws -> Instrument? {
        try ensureConnected()
        guard let db = connection else { return nil }
        if let row = try db.pluck(instruments.filter(isin == instrumentIsin)) {
            return instrumentFromRow(row)
        }
        return nil
    }
    
    func addOrUpdateInstrument(_ instrument: Instrument) throws {
        try ensureConnected()
        guard let db = connection else { return }
        try db.run(instruments.insert(or: .replace, isin <- instrument.isin, ticker <- instrument.ticker, name <- instrument.name, currency <- instrument.currency, quadrantId <- instrument.quadrantId))
    }
    
    func deleteInstrument(_ instrumentIsin: String) throws {
        try ensureConnected()
        guard let db = connection else { return }
        try db.run(instruments.filter(isin == instrumentIsin).delete())
        try db.run(prices.filter(priceIsin == instrumentIsin).delete())
        try db.run(holdings.filter(holdingIsin == instrumentIsin).delete())
    }
    
    func assignQuadrant(instrumentIsin: String, quadrantId newQuadrantId: Int?) throws {
        try ensureConnected()
        guard let db = connection else { return }
        try db.run(instruments.filter(isin == instrumentIsin).update(quadrantId <- newQuadrantId))
    }
    
    func addPrice(_ price: Price) throws {
        try ensureConnected()
        guard let db = connection else { return }
        try db.run(prices.insert(or: .replace, priceIsin <- price.isin, date <- price.date, value <- price.value, priceCurrency <- price.currency))
    }
    
    func deletePrice(isin instrumentIsin: String, date priceDate: String) throws {
        try ensureConnected()
        guard let db = connection else { return }
        try db.run(prices.filter(priceIsin == instrumentIsin && date == priceDate).delete())
    }
    
    func getLatestPrice(forIsin instrumentIsin: String) throws -> Price? {
        try ensureConnected()
        guard let db = connection else { return nil }
        let query = prices.filter(priceIsin == instrumentIsin).order(date.desc).limit(1)
        if let row = try db.pluck(query) { return priceFromRow(row) }
        return nil
    }
    
    func getLastInstrumentUpdateDate() throws -> String? {
        try ensureConnected()
        guard let db = connection else { return nil }
        let query = prices.select(date).order(date.desc).limit(1)
        if let row = try db.pluck(query) { return row[date] }
        return nil
    }
    
    func getPrice(forIsin instrumentIsin: String, date targetDate: String) throws -> Price? {
        try ensureConnected()
        guard let db = connection else { return nil }
        let query = prices.filter(priceIsin == instrumentIsin && date == targetDate).limit(1)
        if let row = try db.pluck(query) { return priceFromRow(row) }
        return nil
    }
    
    func getPriceHistory(forIsin instrumentIsin: String) throws -> [Price] {
        try ensureConnected()
        return try fetchAll(query: prices.filter(priceIsin == instrumentIsin).order(date.desc), mapper: priceFromRow)
    }
    
    func getPriceOnOrBefore(forIsin instrumentIsin: String, date targetDate: String) throws -> Price? {
        try ensureConnected()
        guard let db = connection else { return nil }
        let query = prices.filter(priceIsin == instrumentIsin && date <= targetDate).order(date.desc).limit(1)
        if let row = try db.pluck(query) { return priceFromRow(row) }
        return nil
    }
    
    func getPriceBefore(forIsin instrumentIsin: String, date targetDate: String) throws -> Price? {
        try ensureConnected()
        guard let db = connection else { return nil }
        let query = prices.filter(priceIsin == instrumentIsin && date < targetDate).order(date.desc).limit(1)
        if let row = try db.pluck(query) { return priceFromRow(row) }
        return nil
    }
    
    func addExchangeRate(_ exchangeRate: ExchangeRate) throws {
        try ensureConnected()
        guard let db = connection else { return }
        try db.run(exchangeRates.insert(or: .replace, rateDate <- exchangeRate.date, fromCurrency <- exchangeRate.fromCurrency, toCurrency <- exchangeRate.toCurrency, rate <- exchangeRate.rate))
    }
    
    func getLatestRate(from: String, to: String) throws -> ExchangeRate? {
        try ensureConnected()
        guard let db = connection else { return nil }
        let query = exchangeRates.filter(fromCurrency == from && toCurrency == to).order(rateDate.desc).limit(1)
        if let row = try db.pluck(query) { return exchangeRateFromRow(row) }
        return nil
    }
    
    func getRateOnOrBefore(from: String, to: String, date targetDate: String) throws -> ExchangeRate? {
        try ensureConnected()
        guard let db = connection else { return nil }
        let query = exchangeRates.filter(fromCurrency == from && toCurrency == to && rateDate <= targetDate).order(rateDate.desc).limit(1)
        if let row = try db.pluck(query) { return exchangeRateFromRow(row) }
        return nil
    }
    
    func getAllQuadrants() throws -> [Quadrant] {
        try ensureConnected()
        return try fetchAll(query: quadrants.order(quadName), mapper: quadrantFromRow)
    }
    
    func addQuadrant(name quadrantName: String) throws -> Bool {
        try ensureConnected()
        guard let db = connection else { return false }
        try db.run(quadrants.insert(quadName <- quadrantName))
        return true
    }
    
    func deleteQuadrant(id quadrantIdValue: Int) throws {
        try ensureConnected()
        guard let db = connection else { return }
        try db.run(instruments.filter(quadrantId == quadrantIdValue).update(quadrantId <- nil as Int?))
        try db.run(quadrants.filter(quadId == quadrantIdValue).delete())
    }
    
    func getAllBankAccounts() throws -> [BankAccount] {
        try ensureConnected()
        return try fetchAll(query: bankAccounts.order(bankName, accountName), mapper: bankAccountFromRow)
    }
    
    func addBankAccount(bank: String, account: String) throws -> Bool {
        try ensureConnected()
        guard let db = connection else { return false }
        try db.run(bankAccounts.insert(bankName <- bank, accountName <- account))
        return true
    }
    
    func deleteBankAccount(id accountIdValue: Int) throws {
        try ensureConnected()
        guard let db = connection else { return }
        try db.run(holdings.filter(holdingAccountId == accountIdValue).delete())
        try db.run(bankAccounts.filter(accountId == accountIdValue).delete())
    }
    
    func getHoldings(forAccount accountIdValue: Int) throws -> [Holding] {
        try ensureConnected()
        return try fetchAll(query: holdings.filter(holdingAccountId == accountIdValue), mapper: holdingFromRow)
    }
    
    func getAllHoldings() throws -> [Holding] {
        try ensureConnected()
        return try fetchAll(query: holdings, mapper: holdingFromRow)
    }
    
    func addOrUpdateHolding(_ holding: Holding, now: String) throws {
        try ensureConnected()
        guard let db = connection else { return }
        try db.run(holdings.insert(or: .replace, holdingAccountId <- holding.accountId, holdingIsin <- holding.isin, quantity <- holding.quantity, purchaseDate <- holding.purchaseDate, purchasePrice <- holding.purchasePrice, lastUpdated <- now))
    }
    
    func updateHolding(accountIdValue: Int, instrumentIsin: String, quantity newQuantity: Double, purchaseDate newPurchaseDate: String?, purchasePrice newPurchasePrice: Double?, now: String) throws {
        try ensureConnected()
        guard let db = connection else { return }
        try db.run(holdings.filter(holdingAccountId == accountIdValue && holdingIsin == instrumentIsin).update(quantity <- newQuantity, purchaseDate <- newPurchaseDate, purchasePrice <- newPurchasePrice, lastUpdated <- now))
    }
    
    func deleteHolding(accountIdValue: Int, instrumentIsin: String) throws {
        try ensureConnected()
        guard let db = connection else { return }
        try db.run(holdings.filter(holdingAccountId == accountIdValue && holdingIsin == instrumentIsin).delete())
    }
    
    func getTotalQuantity(forIsin instrumentIsin: String) throws -> Double {
        try ensureConnected()
        guard let db = connection else { return 0 }
        return try db.scalar(holdings.filter(holdingIsin == instrumentIsin).select(quantity.sum)) ?? 0
    }
}

// MARK: - Database Service
@MainActor
class DatabaseService: ObservableObject {
    static let shared = DatabaseService()

    #if os(macOS)
    static func projectRootPath() -> String {
        let home = ProcessInfo.processInfo.environment["HOME"]
            ?? FileManager.default.homeDirectoryForCurrentUser.path
        return (home as NSString).appendingPathComponent("github/Portfolio")
    }
    #endif
    
    private let dbPath: String
    private let dbActor: DatabaseActor
    
    @Published private(set) var storageLogEntries: [StorageLogEntry] = []
    
    var iCloudBackupAvailable: Bool { iCloudBackupContainerURL != nil }
    private var iCloudBackupContainerURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.portfolio.app")
    }
    
    private static let storageLogsKey = "storageLogEntries"
    private static let storageLogsMaxCount = 50
    
    private static let lastBackupTimeKey = "databaseLastICloudBackupTime"
    private static let backupThrottleInterval: TimeInterval = 300 // 5 minutes
    
    private init() {
        self.dbPath = Self.localDatabasePath()
        self.dbActor = DatabaseActor(path: dbPath)
        
        let fm = FileManager.default
        
        #if os(macOS)
        if !fm.fileExists(atPath: dbPath) {
            let legacyPath = (Self.projectRootPath() as NSString).appendingPathComponent("data/stocks.db")
            if fm.fileExists(atPath: legacyPath) {
                let destDir = URL(fileURLWithPath: dbPath).deletingLastPathComponent()
                try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)
                try? fm.copyItem(atPath: legacyPath, toPath: dbPath)
            }
        }
        #endif
        
        var restoredFromICloud = false
        if !fm.fileExists(atPath: dbPath), let containerURL = iCloudBackupContainerURL {
            let backupDir = containerURL.appendingPathComponent("Documents", isDirectory: true).appendingPathComponent("PortfolioBackup", isDirectory: true)
            let backupURL = backupDir.appendingPathComponent("stocks.db")
            if fm.fileExists(atPath: backupURL.path) {
                let destDir = URL(fileURLWithPath: dbPath).deletingLastPathComponent()
                if (try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)) != nil,
                   (try? fm.copyItem(at: backupURL, to: URL(fileURLWithPath: dbPath))) != nil {
                    restoredFromICloud = true
                }
            }
        }
        
        self.storageLogEntries = Self.loadStorageLogsFromDefaults()
        if restoredFromICloud {
            appendStorageLog(message: "Restored database from iCloud backup.", isWarning: false, isError: false)
        }
        appendStorageLog(message: "Database service ready (I/O off main thread).", isWarning: false, isError: false)
        registerBackupOnBackground()
    }
    
    private func logActorError(_ error: Error, _ context: String) {
        AppLogger.databaseLog("\(context): \(error.localizedDescription)", isError: true)
        appendStorageLog(message: "\(context): \(error.localizedDescription)", isWarning: false, isError: true)
    }
    
    private static func localDatabasePath() -> String {
        #if os(iOS)
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return (FileManager.default.temporaryDirectory.appendingPathComponent("PortfolioData", isDirectory: true).appendingPathComponent("stocks.db").path)
        }
        let dataDir = documentsURL.appendingPathComponent("PortfolioData", isDirectory: true)
        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
        return dataDir.appendingPathComponent("stocks.db").path
        #else
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return (FileManager.default.temporaryDirectory.appendingPathComponent("Portfolio/data", isDirectory: true).appendingPathComponent("stocks.db").path)
        }
        let dataDir = appSupport.appendingPathComponent("Portfolio", isDirectory: true).appendingPathComponent("data", isDirectory: true)
        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
        return dataDir.appendingPathComponent("stocks.db").path
        #endif
    }
    
    private func registerBackupOnBackground() {
        #if os(iOS)
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.backupDatabaseToICloudIfThrottled() }
        }
        #elseif os(macOS)
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.backupDatabaseToICloudIfThrottled() }
        }
        #endif
    }
    
    private func backupDatabaseToICloudIfThrottled() {
        let last = UserDefaults.standard.double(forKey: Self.lastBackupTimeKey)
        let lastDate = last > 0 ? Date(timeIntervalSince1970: last) : .distantPast
        guard Date().timeIntervalSince(lastDate) >= Self.backupThrottleInterval else { return }
        backupDatabaseToICloud(completion: nil)
    }
    
    /// Copies the local database file to the user's iCloud container for backup. App always uses the local file only.
    func backupDatabaseToICloud(completion: ((Swift.Result<Void, Error>) -> Void)? = nil) {
        let path = dbPath
        guard FileManager.default.fileExists(atPath: path) else {
            let err = NSError(domain: "DatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Database file not found."])
            completion?(.failure(err))
            return
        }
        guard let containerURL = iCloudBackupContainerURL else {
            let err = NSError(domain: "DatabaseService", code: -2, userInfo: [NSLocalizedDescriptionKey: "iCloud is not available."])
            completion?(.failure(err))
            return
        }
        let backupDir = containerURL.appendingPathComponent("Documents", isDirectory: true).appendingPathComponent("PortfolioBackup", isDirectory: true)
        let backupURL = backupDir.appendingPathComponent("stocks.db")
        
        let lastBackupKey = Self.lastBackupTimeKey
        let completionCapture = completion
        Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            do {
                try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
                if fm.fileExists(atPath: backupURL.path) {
                    try fm.removeItem(at: backupURL)
                }
                try fm.copyItem(atPath: path, toPath: backupURL.path)
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastBackupKey)
                await MainActor.run {
                    Self.shared.appendStorageLog(message: "Backed up to iCloud.", isWarning: false, isError: false)
                    completionCapture?(.success(()))
                }
            } catch {
                await MainActor.run {
                    completionCapture?(.failure(error))
                }
            }
        }
    }
    
    private static func loadStorageLogsFromDefaults() -> [StorageLogEntry] {
        guard let data = UserDefaults.standard.data(forKey: storageLogsKey),
              let decoded = try? JSONDecoder().decode([StorageLogEntry].self, from: data) else { return [] }
        return decoded
    }
    
    private func appendStorageLog(message: String, isWarning: Bool = false, isError: Bool = false) {
        let entry = StorageLogEntry(message: message, isWarning: isWarning, isError: isError)
        storageLogEntries.append(entry)
        if storageLogEntries.count > Self.storageLogsMaxCount {
            storageLogEntries.removeFirst(storageLogEntries.count - Self.storageLogsMaxCount)
        }
        if let encoded = try? JSONEncoder().encode(storageLogEntries) {
            UserDefaults.standard.set(encoded, forKey: Self.storageLogsKey)
        }
        AppLogger.databaseLog(message, isError: false)
    }
    
    /// Closes the database connection so the file can be safely replaced (e.g. before import). Call `reconnectToDatabase()` after replacing the file.
    func closeConnection() async {
        await dbActor.closeConnection()
    }
    
    /// Reopens the database connection to the current path. Call after replacing the database file (e.g. after import).
    func reconnectToDatabase() async {
        do {
            try await dbActor.reconnect()
        } catch {
            logActorError(error, "reconnectToDatabase")
        }
    }
    
    // MARK: - Instruments
    func getAllInstruments() async -> [Instrument] {
        do { return try await dbActor.getAllInstruments() } catch { logActorError(error, "getAllInstruments"); return [] }
    }
    
    func getInstrument(byIsin instrumentIsin: String) async -> Instrument? {
        do { return try await dbActor.getInstrument(byIsin: instrumentIsin) } catch { logActorError(error, "getInstrument"); return nil }
    }
    
    func addOrUpdateInstrument(_ instrument: Instrument) async {
        do { try await dbActor.addOrUpdateInstrument(instrument) } catch { logActorError(error, "addOrUpdateInstrument") }
    }
    
    func deleteInstrument(_ instrumentIsin: String) async {
        do { try await dbActor.deleteInstrument(instrumentIsin) } catch { logActorError(error, "deleteInstrument") }
    }
    
    func assignQuadrant(instrumentIsin: String, quadrantId newQuadrantId: Int?) async {
        do { try await dbActor.assignQuadrant(instrumentIsin: instrumentIsin, quadrantId: newQuadrantId) } catch { logActorError(error, "assignQuadrant") }
    }
    
    // MARK: - Prices
    func addPrice(_ price: Price) async {
        do { try await dbActor.addPrice(price) } catch { logActorError(error, "addPrice") }
    }
    
    func deletePrice(isin instrumentIsin: String, date priceDate: String) async {
        do { try await dbActor.deletePrice(isin: instrumentIsin, date: priceDate) } catch { logActorError(error, "deletePrice") }
    }
    
    func getLatestPrice(forIsin instrumentIsin: String) async -> Price? {
        do { return try await dbActor.getLatestPrice(forIsin: instrumentIsin) } catch { logActorError(error, "getLatestPrice"); return nil }
    }
    
    func getLastInstrumentUpdateDate() async -> String? {
        do { return try await dbActor.getLastInstrumentUpdateDate() } catch { logActorError(error, "getLastInstrumentUpdateDate"); return nil }
    }
    
    func getPrice(forIsin instrumentIsin: String, date targetDate: String) async -> Price? {
        do { return try await dbActor.getPrice(forIsin: instrumentIsin, date: targetDate) } catch { logActorError(error, "getPrice"); return nil }
    }
    
    func getPriceHistory(forIsin instrumentIsin: String) async -> [Price] {
        do { return try await dbActor.getPriceHistory(forIsin: instrumentIsin) } catch { logActorError(error, "getPriceHistory"); return [] }
    }
    
    func getPriceOnOrBefore(forIsin instrumentIsin: String, date targetDate: String) async -> Price? {
        do { return try await dbActor.getPriceOnOrBefore(forIsin: instrumentIsin, date: targetDate) } catch { logActorError(error, "getPriceOnOrBefore"); return nil }
    }
    
    func getPriceBefore(forIsin instrumentIsin: String, date targetDate: String) async -> Price? {
        do { return try await dbActor.getPriceBefore(forIsin: instrumentIsin, date: targetDate) } catch { logActorError(error, "getPriceBefore"); return nil }
    }
    
    // MARK: - Exchange Rates
    func addExchangeRate(_ exchangeRate: ExchangeRate) async {
        do { try await dbActor.addExchangeRate(exchangeRate) } catch { logActorError(error, "addExchangeRate") }
    }
    
    func getLatestRate(from: String, to: String) async -> ExchangeRate? {
        do { return try await dbActor.getLatestRate(from: from, to: to) } catch { logActorError(error, "getLatestRate"); return nil }
    }
    
    func getRateOnOrBefore(from: String, to: String, date targetDate: String) async -> ExchangeRate? {
        do { return try await dbActor.getRateOnOrBefore(from: from, to: to, date: targetDate) } catch { logActorError(error, "getRateOnOrBefore"); return nil }
    }
    
    // MARK: - Quadrants
    func getAllQuadrants() async -> [Quadrant] {
        do { return try await dbActor.getAllQuadrants() } catch { logActorError(error, "getAllQuadrants"); return [] }
    }
    
    func addQuadrant(name quadrantName: String) async -> Bool {
        do { return try await dbActor.addQuadrant(name: quadrantName) } catch { logActorError(error, "addQuadrant"); return false }
    }
    
    func deleteQuadrant(id quadrantIdValue: Int) async {
        do { try await dbActor.deleteQuadrant(id: quadrantIdValue) } catch { logActorError(error, "deleteQuadrant") }
    }
    
    // MARK: - Bank Accounts
    func getAllBankAccounts() async -> [BankAccount] {
        do { return try await dbActor.getAllBankAccounts() } catch { logActorError(error, "getAllBankAccounts"); return [] }
    }
    
    func addBankAccount(bank: String, account: String) async -> Bool {
        do { return try await dbActor.addBankAccount(bank: bank, account: account) } catch { logActorError(error, "addBankAccount"); return false }
    }
    
    func deleteBankAccount(id accountIdValue: Int) async {
        do { try await dbActor.deleteBankAccount(id: accountIdValue) } catch { logActorError(error, "deleteBankAccount") }
    }
    
    // MARK: - Holdings
    func getHoldings(forAccount accountIdValue: Int) async -> [Holding] {
        do { return try await dbActor.getHoldings(forAccount: accountIdValue) } catch { logActorError(error, "getHoldings"); return [] }
    }
    
    func getAllHoldings() async -> [Holding] {
        do { return try await dbActor.getAllHoldings() } catch { logActorError(error, "getAllHoldings"); return [] }
    }
    
    func addOrUpdateHolding(_ holding: Holding) async {
        let now = AppDateFormatter.iso8601.string(from: Date())
        do { try await dbActor.addOrUpdateHolding(holding, now: now) } catch { logActorError(error, "addOrUpdateHolding") }
    }
    
    func updateHolding(accountIdValue: Int, instrumentIsin: String, quantity newQuantity: Double, purchaseDate newPurchaseDate: String?, purchasePrice newPurchasePrice: Double?) async {
        let now = AppDateFormatter.iso8601.string(from: Date())
        do { try await dbActor.updateHolding(accountIdValue: accountIdValue, instrumentIsin: instrumentIsin, quantity: newQuantity, purchaseDate: newPurchaseDate, purchasePrice: newPurchasePrice, now: now) } catch { logActorError(error, "updateHolding") }
    }
    
    func deleteHolding(accountIdValue: Int, instrumentIsin: String) async {
        do { try await dbActor.deleteHolding(accountIdValue: accountIdValue, instrumentIsin: instrumentIsin) } catch { logActorError(error, "deleteHolding") }
    }
    
    func getTotalQuantity(forIsin instrumentIsin: String) async -> Double {
        do { return try await dbActor.getTotalQuantity(forIsin: instrumentIsin) } catch { logActorError(error, "getTotalQuantity"); return 0 }
    }
    
    // MARK: - Database Path
    func getDatabasePath() -> String {
        return dbPath
    }
}
#endif

#if !canImport(SQLite)
@MainActor
class DatabaseService: ObservableObject {
    static let shared = DatabaseService()
    @Published private(set) var storageLogEntries: [StorageLogEntry] = []
    var iCloudBackupAvailable: Bool { false }
    
    private init() {}
    
    func closeConnection() async {}
    func reconnectToDatabase() async {}
    func backupDatabaseToICloud(completion: ((Swift.Result<Void, Error>) -> Void)? = nil) {
        completion?(.failure(NSError(domain: "DatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "SQLite not available"])))
    }
    
    func getAllInstruments() async -> [Instrument] { [] }
    func getInstrument(byIsin instrumentIsin: String) async -> Instrument? { nil }
    func addOrUpdateInstrument(_ instrument: Instrument) async {}
    func deleteInstrument(_ instrumentIsin: String) async {}
    func assignQuadrant(instrumentIsin: String, quadrantId newQuadrantId: Int?) async {}
    
    func addPrice(_ price: Price) async {}
    func deletePrice(isin: String, date priceDate: String) async {}
    func getLatestPrice(forIsin instrumentIsin: String) async -> Price? { nil }
    func getLastInstrumentUpdateDate() async -> String? { nil }
    func getPrice(forIsin instrumentIsin: String, date targetDate: String) async -> Price? { nil }
    func getPriceHistory(forIsin instrumentIsin: String) async -> [Price] { [] }
    func getPriceOnOrBefore(forIsin instrumentIsin: String, date targetDate: String) async -> Price? { nil }
    func getPriceBefore(forIsin instrumentIsin: String, date targetDate: String) async -> Price? { nil }
    
    func addExchangeRate(_ exchangeRate: ExchangeRate) async {}
    func getLatestRate(from: String, to: String) async -> ExchangeRate? { nil }
    func getRateOnOrBefore(from: String, to: String, date targetDate: String) async -> ExchangeRate? { nil }
    
    func getAllQuadrants() async -> [Quadrant] { [] }
    func addQuadrant(name quadrantName: String) async -> Bool { false }
    func deleteQuadrant(id quadrantIdValue: Int) async {}
    
    func getAllBankAccounts() async -> [BankAccount] { [] }
    func addBankAccount(bank: String, account: String) async -> Bool { false }
    func deleteBankAccount(id accountIdValue: Int) async {}
    
    func getHoldings(forAccount accountIdValue: Int) async -> [Holding] { [] }
    func getAllHoldings() async -> [Holding] { [] }
    func addOrUpdateHolding(_ holding: Holding) async {}
    func updateHolding(accountIdValue: Int, instrumentIsin: String, quantity newQuantity: Double, purchaseDate newPurchaseDate: String?, purchasePrice newPurchasePrice: Double?) async {}
    func deleteHolding(accountIdValue: Int, instrumentIsin: String) async {}
    func getTotalQuantity(forIsin instrumentIsin: String) async -> Double { 0 }
    
    func getDatabasePath() -> String {
        #if os(iOS)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return documentsURL.appendingPathComponent("PortfolioData/stocks.db").path
        #else
        let home = ProcessInfo.processInfo.environment["HOME"] ?? FileManager.default.homeDirectoryForCurrentUser.path
        return (home as NSString).appendingPathComponent("github/Portfolio/data/stocks.db")
        #endif
    }
}
#endif
