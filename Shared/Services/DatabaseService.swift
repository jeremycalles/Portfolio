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
// MARK: - Database Service
@MainActor
class DatabaseService: ObservableObject {
    static let shared = DatabaseService()

    #if os(macOS)
    /// Project root path under user home (uses HOME env when set, else FileManager home).
    static func projectRootPath() -> String {
        let home = ProcessInfo.processInfo.environment["HOME"]
            ?? FileManager.default.homeDirectoryForCurrentUser.path
        return (home as NSString).appendingPathComponent("github/Portfolio")
    }
    #endif
    
    private var db: Connection?
    private var dbPath: String
    
    @Published private(set) var storageLogEntries: [StorageLogEntry] = []
    
    /// True when the user's iCloud container is available (for backup only; database is always local).
    var iCloudBackupAvailable: Bool { iCloudBackupContainerURL != nil }
    private var iCloudBackupContainerURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.portfolio.app")
    }
    
    private static let storageLogsKey = "storageLogEntries"
    private static let storageLogsMaxCount = 50
    
    // Tables
    private let instruments = Table("instruments")
    private let prices = Table("prices")
    private let exchangeRates = Table("exchange_rates")
    private let quadrants = Table("quadrants")
    private let bankAccounts = Table("bank_accounts")
    private let holdings = Table("holdings")
    
    // Columns - Instruments
    private let isin = SQLite.Expression<String>("isin")
    private let ticker = SQLite.Expression<String?>("ticker")
    private let name = SQLite.Expression<String?>("name")
    private let currency = SQLite.Expression<String?>("currency")
    private let quadrantId = SQLite.Expression<Int?>("quadrant_id")
    
    // Columns - Prices
    private let priceId = SQLite.Expression<Int>("id")
    private let priceIsin = SQLite.Expression<String>("isin")
    private let date = SQLite.Expression<String>("date")
    private let value = SQLite.Expression<Double>("value")
    private let priceCurrency = SQLite.Expression<String?>("currency")
    
    // Columns - Exchange Rates
    private let rateId = SQLite.Expression<Int>("id")
    private let rateDate = SQLite.Expression<String>("date")
    private let fromCurrency = SQLite.Expression<String>("from_currency")
    private let toCurrency = SQLite.Expression<String>("to_currency")
    private let rate = SQLite.Expression<Double>("rate")
    
    // Columns - Quadrants
    private let quadId = SQLite.Expression<Int>("id")
    private let quadName = SQLite.Expression<String>("name")
    
    // Columns - Bank Accounts
    private let accountId = SQLite.Expression<Int>("id")
    private let bankName = SQLite.Expression<String>("bank_name")
    private let accountName = SQLite.Expression<String>("account_name")
    
    // Columns - Holdings
    private let holdingId = SQLite.Expression<Int>("id")
    private let holdingAccountId = SQLite.Expression<Int>("account_id")
    private let holdingIsin = SQLite.Expression<String>("isin")
    private let quantity = SQLite.Expression<Double>("quantity")
    private let purchaseDate = SQLite.Expression<String?>("purchase_date")
    private let purchasePrice = SQLite.Expression<Double?>("purchase_price")
    private let lastUpdated = SQLite.Expression<String?>("last_updated")
    
    // MARK: - Row-to-Model Mappers
    private func instrumentFromRow(_ row: Row) -> Instrument {
        return Instrument(
            isin: row[isin],
            ticker: row[ticker],
            name: row[name],
            currency: row[currency],
            quadrantId: row[quadrantId]
        )
    }
    
    private func priceFromRow(_ row: Row) -> Price {
        return Price(
            id: row[priceId],
            isin: row[priceIsin],
            date: row[date],
            value: row[value],
            currency: row[priceCurrency]
        )
    }
    
    private func exchangeRateFromRow(_ row: Row) -> ExchangeRate {
        return ExchangeRate(
            id: row[rateId],
            date: row[rateDate],
            fromCurrency: row[fromCurrency],
            toCurrency: row[toCurrency],
            rate: row[rate]
        )
    }
    
    private func quadrantFromRow(_ row: Row) -> Quadrant {
        return Quadrant(
            id: row[quadId],
            name: row[quadName]
        )
    }
    
    private func bankAccountFromRow(_ row: Row) -> BankAccount {
        return BankAccount(
            id: row[accountId],
            bankName: row[bankName],
            accountName: row[accountName]
        )
    }
    
    private func holdingFromRow(_ row: Row) -> Holding {
        return Holding(
            id: row[holdingId],
            accountId: row[holdingAccountId],
            isin: row[holdingIsin],
            quantity: row[quantity],
            purchaseDate: row[purchaseDate],
            purchasePrice: row[purchasePrice],
            lastUpdated: row[lastUpdated]
        )
    }
    
    // MARK: - Generic Fetch Helper
    private func fetchAll<T>(query: QueryType, mapper: (Row) -> T) -> [T] {
        guard let db = db else { return [] }
        var result: [T] = []
        do {
            for row in try db.prepare(query) {
                result.append(mapper(row))
            }
        } catch {
            print("Error fetching: \(error)")
        }
        return result
    }
    
    private static let lastBackupTimeKey = "databaseLastICloudBackupTime"
    private static let backupThrottleInterval: TimeInterval = 300 // 5 minutes
    
    private init() {
        self.dbPath = Self.localDatabasePath()
        
        #if os(macOS)
        // One-time migration: if local path is empty, copy from legacy project path if it exists
        let fm = FileManager.default
        if !fm.fileExists(atPath: dbPath) {
            let legacyPath = (Self.projectRootPath() as NSString).appendingPathComponent("data/stocks.db")
            if fm.fileExists(atPath: legacyPath) {
                let destDir = URL(fileURLWithPath: dbPath).deletingLastPathComponent()
                try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)
                try? fm.copyItem(atPath: legacyPath, toPath: dbPath)
            }
        }
        #endif
        
        self.storageLogEntries = Self.loadStorageLogsFromDefaults()
        connectToDatabase()
        appendStorageLog(message: "Connected to database (local).", isWarning: false, isError: false)
        
        registerBackupOnBackground()
    }
    
    private static func localDatabasePath() -> String {
        #if os(iOS)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dataDir = documentsURL.appendingPathComponent("PortfolioData", isDirectory: true)
        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
        return dataDir.appendingPathComponent("stocks.db").path
        #else
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
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
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fm = FileManager.default
            do {
                try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
                if fm.fileExists(atPath: backupURL.path) {
                    try fm.removeItem(at: backupURL)
                }
                try fm.copyItem(atPath: path, toPath: backupURL.path)
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastBackupKey)
                Task { @MainActor in
                    self?.appendStorageLog(message: "Backed up to iCloud.", isWarning: false, isError: false)
                    completion?(.success(()))
                }
            } catch {
                Task { @MainActor in
                    completion?(.failure(error))
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
        print("[Database] \(message)")
    }
    
    private func connectToDatabase() {
        do {
            db = try Connection(dbPath)
            // Initialize tables if they don't exist
            initializeDatabase()
        } catch {
            print("[Database] Connection failed: \(error)")
        }
    }
    
    /// Closes the database connection so the file can be safely replaced (e.g. before import). Call `reconnectToDatabase()` after replacing the file.
    func closeConnection() {
        db = nil
    }
    
    /// Reopens the database connection to the current path. Call after replacing the database file (e.g. after import) to avoid disk I/O errors from using a stale connection.
    func reconnectToDatabase() {
        db = nil
        connectToDatabase()
    }
    
    private func initializeDatabase() {
        guard let db = db else { return }
        
        do {
            // Create tables if they don't exist
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
            
            // Create indexes for frequently queried columns
            try db.run(prices.createIndex(priceIsin, date, ifNotExists: true))
            try db.run(exchangeRates.createIndex(fromCurrency, toCurrency, rateDate, ifNotExists: true))
            try db.run(holdings.createIndex(holdingIsin, ifNotExists: true))
            try db.run(holdings.createIndex(holdingAccountId, ifNotExists: true))
            
            print("Database tables initialized")
        } catch {
            print("Failed to initialize database: \(error)")
        }
    }
    
    // MARK: - Instruments
    func getAllInstruments() -> [Instrument] {
        return fetchAll(query: instruments, mapper: instrumentFromRow)
    }
    
    func getInstrument(byIsin instrumentIsin: String) -> Instrument? {
        guard let db = db else { return nil }
        
        do {
            if let row = try db.pluck(instruments.filter(isin == instrumentIsin)) {
                return instrumentFromRow(row)
            }
        } catch {
            print("Failed to fetch instrument: \(error)")
        }
        return nil
    }
    
    func addOrUpdateInstrument(_ instrument: Instrument) {
        guard let db = db else { return }
        
        do {
            try db.run(instruments.insert(or: .replace,
                isin <- instrument.isin,
                ticker <- instrument.ticker,
                name <- instrument.name,
                currency <- instrument.currency,
                quadrantId <- instrument.quadrantId
            ))
        } catch {
            print("Failed to add/update instrument: \(error)")
        }
    }
    
    func deleteInstrument(_ instrumentIsin: String) {
        guard let db = db else { return }
        
        do {
            try db.run(instruments.filter(isin == instrumentIsin).delete())
            try db.run(prices.filter(priceIsin == instrumentIsin).delete())
            try db.run(holdings.filter(holdingIsin == instrumentIsin).delete())
        } catch {
            print("Failed to delete instrument: \(error)")
        }
    }
    
    func assignQuadrant(instrumentIsin: String, quadrantId newQuadrantId: Int?) {
        guard let db = db else { return }
        
        do {
            try db.run(instruments.filter(isin == instrumentIsin).update(quadrantId <- newQuadrantId))
        } catch {
            print("Failed to assign quadrant: \(error)")
        }
    }
    
    // MARK: - Prices
    func addPrice(_ price: Price) {
        guard let db = db else { return }
        
        do {
            try db.run(prices.insert(or: .replace,
                priceIsin <- price.isin,
                date <- price.date,
                value <- price.value,
                priceCurrency <- price.currency
            ))
        } catch {
            print("Failed to add price: \(error)")
        }
    }
    
    func deletePrice(isin: String, date priceDate: String) {
        guard let db = db else { return }
        
        do {
            let query = prices.filter(priceIsin == isin && date == priceDate)
            try db.run(query.delete())
        } catch {
            print("Failed to delete price: \(error)")
        }
    }
    
    func getLatestPrice(forIsin instrumentIsin: String) -> Price? {
        guard let db = db else { return nil }
        
        do {
            let query = prices.filter(priceIsin == instrumentIsin).order(date.desc).limit(1)
            if let row = try db.pluck(query) {
                return priceFromRow(row)
            }
        } catch {
            print("Failed to fetch latest price: \(error)")
        }
        return nil
    }
    
    /// Returns the most recent price date across all instruments (yyyy-MM-dd), or nil if no prices.
    func getLastInstrumentUpdateDate() -> String? {
        guard let db = db else { return nil }
        do {
            let query = prices.select(date).order(date.desc).limit(1)
            if let row = try db.pluck(query) {
                return row[date]
            }
        } catch {
            print("Failed to fetch last instrument update date: \(error)")
        }
        return nil
    }
    
    func getPrice(forIsin instrumentIsin: String, date targetDate: String) -> Price? {
        guard let db = db else { return nil }
        
        do {
            let query = prices.filter(priceIsin == instrumentIsin && date == targetDate).limit(1)
            if let row = try db.pluck(query) {
                return priceFromRow(row)
            }
        } catch {
            print("Failed to fetch price: \(error)")
        }
        return nil
    }
    
    func getPriceHistory(forIsin instrumentIsin: String) -> [Price] {
        return fetchAll(query: prices.filter(priceIsin == instrumentIsin).order(date.desc), mapper: priceFromRow)
    }
    
    func getPriceOnOrBefore(forIsin instrumentIsin: String, date targetDate: String, windowDays: Int = 30) -> Price? {
        guard let db = db else { return nil }
        
        do {
            let query = prices
                .filter(priceIsin == instrumentIsin && date <= targetDate)
                .order(date.desc)
                .limit(1)
            
            if let row = try db.pluck(query) {
                return priceFromRow(row)
            }
        } catch {
            print("Failed to fetch price on or before: \(error)")
        }
        return nil
    }
    
    func getPriceBefore(forIsin instrumentIsin: String, date targetDate: String) -> Price? {
        guard let db = db else { return nil }
        
        do {
            let query = prices
                .filter(priceIsin == instrumentIsin && date < targetDate)
                .order(date.desc)
                .limit(1)
            
            if let row = try db.pluck(query) {
                return priceFromRow(row)
            }
        } catch {
            print("Failed to fetch price before: \(error)")
        }
        return nil
    }
    
    // MARK: - Exchange Rates
    func addExchangeRate(_ exchangeRate: ExchangeRate) {
        guard let db = db else { return }
        
        do {
            try db.run(exchangeRates.insert(or: .replace,
                rateDate <- exchangeRate.date,
                fromCurrency <- exchangeRate.fromCurrency,
                toCurrency <- exchangeRate.toCurrency,
                rate <- exchangeRate.rate
            ))
        } catch {
            print("Failed to add exchange rate: \(error)")
        }
    }
    
    func getLatestRate(from: String, to: String) -> ExchangeRate? {
        guard let db = db else { return nil }
        
        do {
            let query = exchangeRates
                .filter(fromCurrency == from && toCurrency == to)
                .order(rateDate.desc)
                .limit(1)
            
            if let row = try db.pluck(query) {
                return exchangeRateFromRow(row)
            }
        } catch {
            print("Failed to fetch exchange rate: \(error)")
        }
        return nil
    }
    
    func getRateOnOrBefore(from: String, to: String, date targetDate: String) -> ExchangeRate? {
        guard let db = db else { return nil }
        
        do {
            // Try to find rate on or before the target date
            let query = exchangeRates
                .filter(fromCurrency == from && toCurrency == to && rateDate <= targetDate)
                .order(rateDate.desc)
                .limit(1)
            
            if let row = try db.pluck(query) {
                return exchangeRateFromRow(row)
            }
        } catch {
            print("Failed to fetch exchange rate on or before \(targetDate): \(error)")
        }
        return nil
    }
    
    // MARK: - Quadrants
    func getAllQuadrants() -> [Quadrant] {
        return fetchAll(query: quadrants.order(quadName), mapper: quadrantFromRow)
    }
    
    func addQuadrant(name quadrantName: String) -> Bool {
        guard let db = db else { return false }
        
        do {
            try db.run(quadrants.insert(quadName <- quadrantName))
            return true
        } catch {
            print("Failed to add quadrant: \(error)")
            return false
        }
    }
    
    func deleteQuadrant(id quadrantIdValue: Int) {
        guard let db = db else { return }
        
        do {
            try db.run(instruments.filter(quadrantId == quadrantIdValue).update(quadrantId <- nil as Int?))
            try db.run(quadrants.filter(quadId == quadrantIdValue).delete())
        } catch {
            print("Failed to delete quadrant: \(error)")
        }
    }
    
    // MARK: - Bank Accounts
    func getAllBankAccounts() -> [BankAccount] {
        return fetchAll(query: bankAccounts.order(bankName, accountName), mapper: bankAccountFromRow)
    }
    
    func addBankAccount(bank: String, account: String) -> Bool {
        guard let db = db else { return false }
        
        do {
            try db.run(bankAccounts.insert(bankName <- bank, accountName <- account))
            return true
        } catch {
            print("Failed to add bank account: \(error)")
            return false
        }
    }
    
    func deleteBankAccount(id accountIdValue: Int) {
        guard let db = db else { return }
        
        do {
            try db.run(holdings.filter(holdingAccountId == accountIdValue).delete())
            try db.run(bankAccounts.filter(accountId == accountIdValue).delete())
        } catch {
            print("Failed to delete bank account: \(error)")
        }
    }
    
    // MARK: - Holdings
    func getHoldings(forAccount accountIdValue: Int) -> [Holding] {
        return fetchAll(query: holdings.filter(holdingAccountId == accountIdValue), mapper: holdingFromRow)
    }
    
    func getAllHoldings() -> [Holding] {
        return fetchAll(query: holdings, mapper: holdingFromRow)
    }
    
    func addOrUpdateHolding(_ holding: Holding) {
        guard let db = db else { return }
        
        let now = AppDateFormatter.iso8601.string(from: Date())
        
        do {
            try db.run(holdings.insert(or: .replace,
                holdingAccountId <- holding.accountId,
                holdingIsin <- holding.isin,
                quantity <- holding.quantity,
                purchaseDate <- holding.purchaseDate,
                purchasePrice <- holding.purchasePrice,
                lastUpdated <- now
            ))
        } catch {
            print("Failed to add/update holding: \(error)")
        }
    }
    
    func updateHolding(accountIdValue: Int, instrumentIsin: String, quantity newQuantity: Double, purchaseDate newPurchaseDate: String?, purchasePrice newPurchasePrice: Double?) {
        guard let db = db else { return }
        let now = AppDateFormatter.iso8601.string(from: Date())
        do {
            try db.run(holdings.filter(holdingAccountId == accountIdValue && holdingIsin == instrumentIsin).update(
                quantity <- newQuantity,
                purchaseDate <- newPurchaseDate,
                purchasePrice <- newPurchasePrice,
                lastUpdated <- now
            ))
        } catch {
            print("Failed to update holding: \(error)")
        }
    }
    
    func deleteHolding(accountIdValue: Int, instrumentIsin: String) {
        guard let db = db else { return }
        
        do {
            try db.run(holdings.filter(holdingAccountId == accountIdValue && holdingIsin == instrumentIsin).delete())
        } catch {
            print("Failed to delete holding: \(error)")
        }
    }
    
    func getTotalQuantity(forIsin instrumentIsin: String) -> Double {
        guard let db = db else { return 0 }
        do {
            return try db.scalar(holdings.filter(holdingIsin == instrumentIsin).select(quantity.sum)) ?? 0
        } catch {
            print("Failed to get total quantity: \(error)")
            return 0
        }
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
    
    func closeConnection() {}
    func reconnectToDatabase() {}
    func backupDatabaseToICloud(completion: ((Swift.Result<Void, Error>) -> Void)? = nil) {
        completion?(.failure(NSError(domain: "DatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "SQLite not available"])))
    }
    
    func getAllInstruments() -> [Instrument] { [] }
    func getInstrument(byIsin instrumentIsin: String) -> Instrument? { nil }
    func addOrUpdateInstrument(_ instrument: Instrument) {}
    func deleteInstrument(_ instrumentIsin: String) {}
    func assignQuadrant(instrumentIsin: String, quadrantId newQuadrantId: Int?) {}
    
    func addPrice(_ price: Price) {}
    func deletePrice(isin: String, date priceDate: String) {}
    func getLatestPrice(forIsin instrumentIsin: String) -> Price? { nil }
    func getLastInstrumentUpdateDate() -> String? { nil }
    func getPrice(forIsin instrumentIsin: String, date targetDate: String) -> Price? { nil }
    func getPriceHistory(forIsin instrumentIsin: String) -> [Price] { [] }
    func getPriceOnOrBefore(forIsin instrumentIsin: String, date targetDate: String, windowDays: Int = 30) -> Price? { nil }
    func getPriceBefore(forIsin instrumentIsin: String, date targetDate: String) -> Price? { nil }
    
    func addExchangeRate(_ exchangeRate: ExchangeRate) {}
    func getLatestRate(from: String, to: String) -> ExchangeRate? { nil }
    func getRateOnOrBefore(from: String, to: String, date targetDate: String) -> ExchangeRate? { nil }
    
    func getAllQuadrants() -> [Quadrant] { [] }
    func addQuadrant(name quadrantName: String) -> Bool { false }
    func deleteQuadrant(id quadrantIdValue: Int) {}
    
    func getAllBankAccounts() -> [BankAccount] { [] }
    func addBankAccount(bank: String, account: String) -> Bool { false }
    func deleteBankAccount(id accountIdValue: Int) {}
    
    func getHoldings(forAccount accountIdValue: Int) -> [Holding] { [] }
    func getAllHoldings() -> [Holding] { [] }
    func addOrUpdateHolding(_ holding: Holding) {}
    func updateHolding(accountIdValue: Int, instrumentIsin: String, quantity newQuantity: Double, purchaseDate newPurchaseDate: String?, purchasePrice newPurchasePrice: Double?) {}
    func deleteHolding(accountIdValue: Int, instrumentIsin: String) {}
    func getTotalQuantity(forIsin instrumentIsin: String) -> Double { 0 }
    
    func getDatabasePath() -> String {
        #if os(iOS)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent("PortfolioData/stocks.db").path
        #else
        let home = ProcessInfo.processInfo.environment["HOME"] ?? FileManager.default.homeDirectoryForCurrentUser.path
        return (home as NSString).appendingPathComponent("github/Portfolio/data/stocks.db")
        #endif
    }
}
#endif
