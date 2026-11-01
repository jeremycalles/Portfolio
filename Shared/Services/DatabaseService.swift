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
actor DatabaseActor {
    private let dbPath: String
    private var connection: Connection?
    
    init(path: String) {
        self.dbPath = path
    }
    
    private func ensureConnected() throws {
        if connection == nil {
            connection = try Connection(dbPath)
            do { try initializeDatabase() }
            catch { connection = nil; throw error }
        }
    }
    
    private let instruments = Table("instruments")
    private let prices = Table("prices")
    private let exchangeRates = Table("exchange_rates")
    private let quadrants = Table("quadrants")
    private let bankAccounts = Table("bank_accounts")
    private let holdings = Table("holdings")
    private let holdingTransactions = Table("holding_transactions")
    
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
    private let txId = SQLite.Expression<Int>("id")
    private let txAccountId = SQLite.Expression<Int>("account_id")
    private let txIsin = SQLite.Expression<String>("isin")
    private let txDate = SQLite.Expression<String>("date")
    private let txQuantityDelta = SQLite.Expression<Double>("quantity_delta")
    private let txUnitPrice = SQLite.Expression<Double?>("unit_price")
    private let txCreatedAt = SQLite.Expression<String?>("created_at")
    private let txKind = SQLite.Expression<String>("kind")
    private let txFees = SQLite.Expression<Double?>("fees")
    private let txNote = SQLite.Expression<String?>("note")
    
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
    private func holdingTransactionFromRow(_ row: Row) -> HoldingTransaction {
        HoldingTransaction(
            id: row[txId],
            accountId: row[txAccountId],
            isin: row[txIsin],
            date: row[txDate],
            quantityDelta: row[txQuantityDelta],
            unitPrice: row[txUnitPrice],
            createdAt: row[txCreatedAt],
            kind: HoldingTransactionKind(rawValue: row[txKind]) ?? .adjustment,
            fees: row[txFees],
            note: row[txNote]
        )
    }
    
    private func fetchAll<T>(query: QueryType, mapper: (Row) -> T) throws -> [T] {
        guard let db = connection else { return [] }
        var result: [T] = []
        for row in try db.prepare(query) {
            result.append(mapper(row))
        }
        return result
    }
    
    private func initializeDatabase(_ target: Connection? = nil) throws {
        guard let db = target ?? connection else { return }
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
        try db.run(holdingTransactions.create(ifNotExists: true) { t in
            t.column(txId, primaryKey: .autoincrement)
            t.column(txAccountId)
            t.column(txIsin)
            t.column(txDate)
            t.column(txQuantityDelta)
            t.column(txUnitPrice)
            t.column(txCreatedAt)
            t.column(txKind, defaultValue: HoldingTransactionKind.adjustment.rawValue)
            t.column(txFees)
            t.column(txNote)
        })
        try addHoldingTransactionColumnsIfNeeded(db)
        try db.run(holdingTransactions.createIndex(txAccountId, txIsin, txDate, ifNotExists: true))
        try migrateNaturalKeys(db)
    }

    /// Existing installs predate the transaction metadata columns. SQLite.swift's
    /// `create(ifNotExists:)` does not alter an existing table, so migrate additively.
    private func addHoldingTransactionColumnsIfNeeded(_ db: Connection) throws {
        var columns = Set<String>()
        for row in try db.prepare("PRAGMA table_info(holding_transactions)") {
            if let name = row[1] as? String {
                columns.insert(name)
            }
        }
        let addedKind = !columns.contains("kind")
        if addedKind {
            try db.run("ALTER TABLE holding_transactions ADD COLUMN kind TEXT NOT NULL DEFAULT 'adjustment'")
        }
        if !columns.contains("fees") {
            try db.run("ALTER TABLE holding_transactions ADD COLUMN fees REAL")
        }
        if !columns.contains("note") {
            try db.run("ALTER TABLE holding_transactions ADD COLUMN note TEXT")
        }
        // Only retag legacy rows when `kind` was just introduced; later adjustments stay adjustments.
        if addedKind {
            try db.run("""
                UPDATE holding_transactions
                SET kind = CASE WHEN quantity_delta < 0 THEN 'sell' ELSE 'opening' END
                WHERE kind = 'adjustment'
                """)
        }
    }
    
    /// Deduplicate rows created by `insert(or: .replace)` on autoincrement PKs, then
    /// add UNIQUE indexes so later replaces actually upsert.
    private func migrateNaturalKeys(_ db: Connection) throws {
        try db.run("DELETE FROM prices WHERE id NOT IN (SELECT id FROM (SELECT MAX(id) AS id FROM prices GROUP BY isin, date))")
        try db.run("DELETE FROM exchange_rates WHERE id NOT IN (SELECT id FROM (SELECT MAX(id) AS id FROM exchange_rates GROUP BY from_currency, to_currency, date))")
        try db.run("DELETE FROM holdings WHERE id NOT IN (SELECT id FROM (SELECT MAX(id) AS id FROM holdings GROUP BY account_id, isin))")
        
        try db.run("""
            UPDATE holdings SET account_id = (
                SELECT MIN(kept.id) FROM bank_accounts kept
                INNER JOIN bank_accounts cur ON cur.id = holdings.account_id
                WHERE kept.bank_name = cur.bank_name AND kept.account_name = cur.account_name
            )
            WHERE account_id NOT IN (
                SELECT id FROM (SELECT MIN(id) AS id FROM bank_accounts GROUP BY bank_name, account_name)
            )
            """)
        try db.run("DELETE FROM bank_accounts WHERE id NOT IN (SELECT id FROM (SELECT MIN(id) AS id FROM bank_accounts GROUP BY bank_name, account_name))")
        
        try db.run("CREATE UNIQUE INDEX IF NOT EXISTS prices_unique_isin_date ON prices (isin, date)")
        try db.run("CREATE UNIQUE INDEX IF NOT EXISTS exchange_rates_unique_pair_date ON exchange_rates (from_currency, to_currency, date)")
        try db.run("CREATE UNIQUE INDEX IF NOT EXISTS holdings_unique_account_isin ON holdings (account_id, isin)")
        try db.run("CREATE UNIQUE INDEX IF NOT EXISTS bank_accounts_unique_bank_account ON bank_accounts (bank_name, account_name)")
    }
    
    func closeConnection() {
        connection = nil
    }
    
    func reconnect() throws {
        connection = nil
        try ensureConnected()
    }
    
    enum BackupError: Error { case invalidFile, unavailable, recoveryRequired }

    /// SQLite's backup API includes committed WAL pages, unlike copying the live file.
    func exportSnapshot(to url: URL) throws {
        try ensureConnected()
        guard let connection else { throw BackupError.unavailable }
        let destination = try Connection(url.path)
        try connection.backup(usingConnection: destination).step()
    }

    private func validateBackup(_ db: Connection) throws {
        guard try db.scalar("PRAGMA integrity_check") as? String == "ok" else { throw BackupError.invalidFile }
        let required: [String: Set<String>] = [
            "instruments": ["isin", "ticker", "name", "currency", "quadrant_id"],
            "prices": ["id", "isin", "date", "value", "currency"],
            "exchange_rates": ["id", "date", "from_currency", "to_currency", "rate"],
            "quadrants": ["id", "name"],
            "bank_accounts": ["id", "bank_name", "account_name"],
            "holdings": ["id", "account_id", "isin", "quantity", "purchase_date", "purchase_price", "last_updated"]
        ]
        for (table, columns) in required {
            let found = Set(try db.prepare("PRAGMA table_info(\(table))").compactMap { $0[1] as? String })
            guard columns.isSubset(of: found) else { throw BackupError.invalidFile }
        }
        // Backups may predate the ledger, but an existing ledger must be structurally valid.
        if try db.scalar("SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name = 'holding_transactions'") as? Int64 == 1 {
            let found = Set(try db.prepare("PRAGMA table_info(holding_transactions)").compactMap { $0[1] as? String })
            guard Set(["id", "account_id", "isin", "date", "quantity_delta", "unit_price", "created_at"]).isSubset(of: found) else {
                throw BackupError.invalidFile
            }
        }
    }

    /// Validates and migrates a staging copy before touching the active database.
    /// All steps are synchronous on this actor, so writes cannot interleave with restore.
    func restoreSnapshot(from url: URL) throws {
        let fm = FileManager.default
        let live = URL(fileURLWithPath: dbPath)
        let staging = live.deletingLastPathComponent().appendingPathComponent("restore-\(UUID().uuidString).db")
        let recovery = URL(fileURLWithPath: dbPath + ".recovery")
        let nextRecovery = live.deletingLastPathComponent().appendingPathComponent("recovery-\(UUID().uuidString).db")
        defer {
            try? fm.removeItem(at: staging)
            try? fm.removeItem(at: nextRecovery)
        }
        do {
            let source = try Connection(url.path, readonly: true)
            try validateBackup(source)
            let candidate = try Connection(staging.path)
            try source.backup(usingConnection: candidate).step()
            try initializeDatabase(candidate)
            try validateBackup(candidate)
        } catch { throw BackupError.invalidFile }
        try exportSnapshot(to: nextRecovery)
        if fm.fileExists(atPath: recovery.path) {
            _ = try fm.replaceItemAt(recovery, withItemAt: nextRecovery)
        } else {
            try fm.moveItem(at: nextRecovery, to: recovery)
        }
        connection = nil
        // The recovery snapshot already contains committed WAL data. Remove old
        // sidecars only after closing the connection, before swapping the main file.
        do {
            for suffix in ["-wal", "-shm", "-journal"] {
                let path = dbPath + suffix
                if fm.fileExists(atPath: path) { try fm.removeItem(atPath: path) }
            }
            _ = try fm.replaceItemAt(live, withItemAt: staging)
            try reconnect()
        } catch {
            connection = nil
            // Leave the recovery file available even if the filesystem prevents rollback.
            let rollback = live.deletingLastPathComponent().appendingPathComponent("rollback-\(UUID().uuidString).db")
            defer { try? fm.removeItem(at: rollback) }
            do {
                try fm.copyItem(at: recovery, to: rollback)
                for suffix in ["-wal", "-shm", "-journal"] {
                    let path = dbPath + suffix
                    if fm.fileExists(atPath: path) { try fm.removeItem(atPath: path) }
                }
                if fm.fileExists(atPath: live.path) {
                    _ = try fm.replaceItemAt(live, withItemAt: rollback)
                } else { try fm.moveItem(at: rollback, to: live) }
                try reconnect()
            } catch { throw BackupError.recoveryRequired }
            throw error
        }
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
    
    func createInstrument(_ instrument: Instrument, price: Price?) throws {
        try ensureConnected()
        guard let db = connection else { throw BackupError.unavailable }
        if let price, !price.value.isFinite || price.value < 0 { throw BackupError.invalidFile }
        try db.transaction {
            try addOrUpdateInstrument(instrument)
            if let price { try addPrice(price) }
        }
    }

    func deletePositionWithHistory(accountId: Int, isin: String) throws {
        try ensureConnected()
        guard let db = connection else { throw BackupError.unavailable }
        try db.transaction {
            try deleteHoldingTransactions(accountId: accountId, isin: isin)
            try deleteHolding(accountIdValue: accountId, instrumentIsin: isin)
        }
    }

    func deleteInstrument(_ instrumentIsin: String) throws {
        try ensureConnected()
        guard let db = connection else { return }
        try db.transaction {
            try db.run(instruments.filter(isin == instrumentIsin).delete())
            try db.run(prices.filter(priceIsin == instrumentIsin).delete())
            try db.run(holdings.filter(holdingIsin == instrumentIsin).delete())
            try db.run(holdingTransactions.filter(txIsin == instrumentIsin).delete())
        }
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

    func getLatestPrices(forIsins instrumentIsins: [String]) throws -> [Price] {
        try ensureConnected()
        guard !instrumentIsins.isEmpty else { return [] }
        let rows = try fetchAll(
            query: prices
                .filter(instrumentIsins.contains(priceIsin))
                .order(priceIsin.asc, date.desc),
            mapper: priceFromRow
        )
        var seen: Set<String> = []
        return rows.filter { seen.insert($0.isin).inserted }
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

    func getPriceHistory(forIsins instrumentIsins: [String]) throws -> [Price] {
        try ensureConnected()
        guard !instrumentIsins.isEmpty else { return [] }
        return try fetchAll(
            query: prices.filter(instrumentIsins.contains(priceIsin)).order(priceIsin.asc, date.asc),
            mapper: priceFromRow
        )
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

    func getEarliestPrice(forIsin instrumentIsin: String) throws -> Price? {
        try ensureConnected()
        guard let db = connection else { return nil }
        let query = prices.filter(priceIsin == instrumentIsin).order(date.asc).limit(1)
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
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    func addQuadrant(name quadrantName: String) throws -> Bool {
        try ensureConnected()
        guard let db = connection else { return false }
        let trimmedName = quadrantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        try db.run(quadrants.insert(quadName <- trimmedName))
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
            .filter { !$0.bankName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    func addBankAccount(bank: String, account: String) throws -> Bool {
        try ensureConnected()
        guard let db = connection else { return false }
        let trimmedBank = bank.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBank.isEmpty, !trimmedAccount.isEmpty else { return false }
        let existing = bankAccounts.filter(bankName == trimmedBank && accountName == trimmedAccount)
        if try db.pluck(existing) != nil { return false }
        try db.run(bankAccounts.insert(bankName <- trimmedBank, accountName <- trimmedAccount))
        return true
    }
    
    func deleteBankAccount(id accountIdValue: Int) throws {
        try ensureConnected()
        guard let db = connection else { return }
        try db.transaction {
            try db.run(holdingTransactions.filter(txAccountId == accountIdValue).delete())
            try db.run(holdings.filter(holdingAccountId == accountIdValue).delete())
            try db.run(bankAccounts.filter(accountId == accountIdValue).delete())
        }
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

    func saveTransaction(_ transaction: HoldingTransaction, now: String, updating: Bool) throws {
        try ensureConnected()
        guard let db = connection else { throw BackupError.unavailable }
        guard transaction.quantityDelta.isFinite, abs(transaction.quantityDelta) > HoldingLedger.epsilon,
              transaction.unitPrice.map({ $0.isFinite && $0 >= 0 }) ?? true,
              transaction.fees.map({ $0.isFinite && $0 >= 0 }) ?? true else { throw HoldingLedgerValidationError.invalidQuantity }
        try db.transaction {
            if updating { try updateHoldingTransaction(transaction, now: now) }
            else { try addHoldingTransaction(transaction, now: now) }
            let ledger = try getHoldingTransactions(accountId: transaction.accountId, isin: transaction.isin)
            try HoldingLedger.validateSequence(ledger)
            try synchronizeHoldingFromTransactions(accountId: transaction.accountId, isin: transaction.isin, now: now)
        }
    }

    func removeTransaction(id: Int, now: String) throws {
        try ensureConnected()
        guard let db = connection, let row = try db.pluck(holdingTransactions.filter(txId == id)) else { throw BackupError.unavailable }
        let transaction = holdingTransactionFromRow(row)
        try db.transaction {
            try deleteHoldingTransaction(id: id)
            try HoldingLedger.validateSequence(getHoldingTransactions(accountId: transaction.accountId, isin: transaction.isin))
            try synchronizeHoldingFromTransactions(accountId: transaction.accountId, isin: transaction.isin, now: now)
        }
    }

    func savePrice(_ price: Price, replacingDate: String?) throws {
        try ensureConnected()
        guard let db = connection, price.value.isFinite, price.value >= 0 else { throw BackupError.unavailable }
        try db.transaction {
            try addPrice(price)
            if let replacingDate, replacingDate != price.date { try deletePrice(isin: price.isin, date: replacingDate) }
        }
    }

    func addHoldingTransaction(_ transaction: HoldingTransaction, now: String) throws {
        try ensureConnected()
        guard let db = connection else { return }
        try db.run(holdingTransactions.insert(
            txAccountId <- transaction.accountId,
            txIsin <- transaction.isin,
            txDate <- transaction.date,
            txQuantityDelta <- transaction.quantityDelta,
            txUnitPrice <- transaction.unitPrice,
            txCreatedAt <- transaction.createdAt ?? now,
            txKind <- transaction.kind.rawValue,
            txFees <- transaction.fees,
            txNote <- transaction.note
        ))
    }

    func updateHoldingTransaction(_ transaction: HoldingTransaction, now: String) throws {
        try ensureConnected()
        guard let db = connection, let id = transaction.id else { return }
        try db.run(holdingTransactions.filter(txId == id).update(
            txAccountId <- transaction.accountId,
            txIsin <- transaction.isin,
            txDate <- transaction.date,
            txQuantityDelta <- transaction.quantityDelta,
            txUnitPrice <- transaction.unitPrice,
            txKind <- transaction.kind.rawValue,
            txFees <- transaction.fees,
            txNote <- transaction.note,
            txCreatedAt <- transaction.createdAt ?? now
        ))
    }

    func deleteHoldingTransaction(id: Int) throws {
        try ensureConnected()
        guard let db = connection else { return }
        try db.run(holdingTransactions.filter(txId == id).delete())
    }

    func deleteHoldingTransactions(accountId accountIdValue: Int, isin instrumentIsin: String) throws {
        try ensureConnected()
        guard let db = connection else { return }
        try db.run(
            holdingTransactions
                .filter(txAccountId == accountIdValue && txIsin == instrumentIsin)
                .delete()
        )
    }

    /// Rebuilds the live holding cache from its ledger. Closed positions are removed
    /// from `holdings`, while their transaction history remains available to charts.
    func synchronizeHoldingFromTransactions(
        accountId accountIdValue: Int,
        isin instrumentIsin: String,
        now: String
    ) throws {
        try ensureConnected()
        guard let db = connection else { return }
        let query = holdingTransactions.filter(txAccountId == accountIdValue && txIsin == instrumentIsin)
        let derived = try db.scalar(query.select(txQuantityDelta.sum)) ?? 0
        let holdingQuery = holdings.filter(holdingAccountId == accountIdValue && holdingIsin == instrumentIsin)
        if derived > 1e-12 {
            if try db.pluck(holdingQuery) != nil {
                try db.run(holdingQuery.update(quantity <- derived, lastUpdated <- now))
            } else {
                try db.run(holdings.insert(
                    holdingAccountId <- accountIdValue,
                    holdingIsin <- instrumentIsin,
                    quantity <- derived,
                    purchaseDate <- nil,
                    purchasePrice <- nil,
                    lastUpdated <- now
                ))
            }
        } else {
            try db.run(holdingQuery.delete())
        }
    }

    func getAllHoldingTransactions() throws -> [HoldingTransaction] {
        try ensureConnected()
        return try fetchAll(query: holdingTransactions.order(txDate.asc, txId.asc), mapper: holdingTransactionFromRow)
    }

    func getHoldingTransactions(forIsin instrumentIsin: String) throws -> [HoldingTransaction] {
        try ensureConnected()
        return try fetchAll(
            query: holdingTransactions.filter(txIsin == instrumentIsin).order(txDate.asc, txId.asc),
            mapper: holdingTransactionFromRow
        )
    }

    func getHoldingTransactions(accountId accountIdValue: Int, isin instrumentIsin: String) throws -> [HoldingTransaction] {
        try ensureConnected()
        return try fetchAll(
            query: holdingTransactions.filter(txAccountId == accountIdValue && txIsin == instrumentIsin).order(txDate.asc, txId.asc),
            mapper: holdingTransactionFromRow
        )
    }

    /// One-time legacy migration: make the ledger add up to every live holding and
    /// remove transactions whose account or instrument no longer exists.
    func reconcileHoldingTransactions(now: String, today: String) throws {
        try ensureConnected()
        guard let db = connection else { return }

        try db.run("""
            DELETE FROM holding_transactions
            WHERE account_id NOT IN (SELECT id FROM bank_accounts)
               OR isin NOT IN (SELECT isin FROM instruments)
            """)

        let existing = try getAllHoldings()
        let allTransactions = try getAllHoldingTransactions()
        let sums = Dictionary(grouping: allTransactions) { "\($0.accountId)|\($0.isin)" }
            .mapValues { $0.reduce(0) { $0 + $1.quantityDelta } }

        for holding in existing {
            let key = "\(holding.accountId)|\(holding.isin)"
            let difference = holding.quantity - (sums[key] ?? 0)
            guard abs(difference) > 1e-12 else { continue }

            let earliestPriceQuery = prices
                .filter(priceIsin == holding.isin)
                .order(date.asc)
                .limit(1)
            let earliestPriceDate = try db.pluck(earliestPriceQuery).map { $0[date] }
            let openingDate = holding.purchaseDate ?? earliestPriceDate ?? today
            let estimated = holding.purchaseDate == nil
            try addHoldingTransaction(
                HoldingTransaction(
                    id: nil,
                    accountId: holding.accountId,
                    isin: holding.isin,
                    date: openingDate,
                    quantityDelta: difference,
                    unitPrice: holding.purchasePrice,
                    createdAt: now,
                    kind: .opening,
                    fees: nil,
                    note: estimated ? HoldingLedger.estimatedOpeningNote : nil
                ),
                now: now
            )
        }
    }
}

// MARK: - Database Service
@MainActor
class DatabaseService: ObservableObject {
    static let shared = DatabaseService()

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
        let backupActor = dbActor
        Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            do {
                try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
                let staged = backupDir.appendingPathComponent("backup-\(UUID().uuidString).db")
                defer { try? fm.removeItem(at: staged) }
                try await backupActor.exportSnapshot(to: staged)
                if fm.fileExists(atPath: backupURL.path) {
                    _ = try fm.replaceItemAt(backupURL, withItemAt: staged)
                } else { try fm.moveItem(at: staged, to: backupURL) }
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
    
    var recoveryBackupURL: URL? {
        let url = URL(fileURLWithPath: getDatabasePath() + ".recovery")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func exportSnapshot() async throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PortfolioBackup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("PortfolioVault.db")
        try await dbActor.exportSnapshot(to: url)
        return url
    }

    func restoreSnapshot(from url: URL) async throws {
        try await dbActor.restoreSnapshot(from: url)
    }

    func createInstrument(_ instrument: Instrument, price: Price?) async -> Bool {
        do { try await dbActor.createInstrument(instrument, price: price); return true }
        catch { logActorError(error, "createInstrument"); return false }
    }

    func deletePositionWithHistory(accountId: Int, isin: String) async -> Bool {
        do { try await dbActor.deletePositionWithHistory(accountId: accountId, isin: isin); return true }
        catch { logActorError(error, "deletePositionWithHistory"); return false }
    }

    // MARK: - Instruments
    func getAllInstruments() async -> [Instrument] {
        do { return try await dbActor.getAllInstruments() } catch { logActorError(error, "getAllInstruments"); return [] }
    }
    
    func getInstrument(byIsin instrumentIsin: String) async -> Instrument? {
        do { return try await dbActor.getInstrument(byIsin: instrumentIsin) } catch { logActorError(error, "getInstrument"); return nil }
    }
    
    @discardableResult
    func addOrUpdateInstrument(_ instrument: Instrument) async -> Bool {
        do { try await dbActor.addOrUpdateInstrument(instrument); return true }
        catch { logActorError(error, "addOrUpdateInstrument"); return false }
    }
    
    @discardableResult
    func deleteInstrument(_ instrumentIsin: String) async -> Bool {
        do { try await dbActor.deleteInstrument(instrumentIsin); return true }
        catch { logActorError(error, "deleteInstrument"); return false }
    }
    
    func assignQuadrant(instrumentIsin: String, quadrantId newQuadrantId: Int?) async {
        do { try await dbActor.assignQuadrant(instrumentIsin: instrumentIsin, quadrantId: newQuadrantId) } catch { logActorError(error, "assignQuadrant") }
    }
    
    // MARK: - Prices
    func addPrice(_ price: Price) async {
        do { try await dbActor.addPrice(price) } catch { logActorError(error, "addPrice") }
    }
    
    func savePrice(_ price: Price, replacingDate: String? = nil) async -> Bool {
        do { try await dbActor.savePrice(price, replacingDate: replacingDate); return true }
        catch { logActorError(error, "savePrice"); return false }
    }

    @discardableResult
    func deletePrice(isin instrumentIsin: String, date priceDate: String) async -> Bool {
        do { try await dbActor.deletePrice(isin: instrumentIsin, date: priceDate); return true }
        catch { logActorError(error, "deletePrice"); return false }
    }
    
    func getLatestPrice(forIsin instrumentIsin: String) async -> Price? {
        do { return try await dbActor.getLatestPrice(forIsin: instrumentIsin) } catch { logActorError(error, "getLatestPrice"); return nil }
    }

    func getLatestPrices(forIsins instrumentIsins: [String]) async -> [Price] {
        do { return try await dbActor.getLatestPrices(forIsins: instrumentIsins) } catch { logActorError(error, "getLatestPrices"); return [] }
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

    func getPriceHistory(forIsins instrumentIsins: [String]) async -> [Price] {
        do { return try await dbActor.getPriceHistory(forIsins: instrumentIsins) } catch { logActorError(error, "getPriceHistoryBulk"); return [] }
    }
    
    func getPriceOnOrBefore(forIsin instrumentIsin: String, date targetDate: String) async -> Price? {
        do { return try await dbActor.getPriceOnOrBefore(forIsin: instrumentIsin, date: targetDate) } catch { logActorError(error, "getPriceOnOrBefore"); return nil }
    }
    
    func getPriceBefore(forIsin instrumentIsin: String, date targetDate: String) async -> Price? {
        do { return try await dbActor.getPriceBefore(forIsin: instrumentIsin, date: targetDate) } catch { logActorError(error, "getPriceBefore"); return nil }
    }

    func getEarliestPrice(forIsin instrumentIsin: String) async -> Price? {
        do { return try await dbActor.getEarliestPrice(forIsin: instrumentIsin) } catch { logActorError(error, "getEarliestPrice"); return nil }
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
    
    @discardableResult
    func deleteBankAccount(id accountIdValue: Int) async -> Bool {
        do { try await dbActor.deleteBankAccount(id: accountIdValue); return true }
        catch { logActorError(error, "deleteBankAccount"); return false }
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

    @discardableResult
    func addHoldingTransaction(
        accountId: Int,
        isin: String,
        date: String,
        quantityDelta: Double,
        unitPrice: Double?,
        kind: HoldingTransactionKind? = nil,
        fees: Double? = nil,
        note: String? = nil
    ) async -> Bool {
        let now = AppDateFormatter.iso8601.string(from: Date())
        let tx = HoldingTransaction(
            id: nil,
            accountId: accountId,
            isin: isin,
            date: date,
            quantityDelta: quantityDelta,
            unitPrice: unitPrice,
            createdAt: now,
            kind: kind ?? (quantityDelta < 0 ? .sell : .buy),
            fees: fees,
            note: note
        )
        do { try await dbActor.saveTransaction(tx, now: now, updating: false); return true }
        catch { logActorError(error, "addHoldingTransaction"); return false }
    }

    @discardableResult
    func updateHoldingTransaction(_ transaction: HoldingTransaction) async -> Bool {
        let now = AppDateFormatter.iso8601.string(from: Date())
        do { try await dbActor.saveTransaction(transaction, now: now, updating: true); return true }
        catch { logActorError(error, "updateHoldingTransaction"); return false }
    }

    @discardableResult
    func deleteHoldingTransaction(id: Int) async -> Bool {
        do { try await dbActor.removeTransaction(id: id, now: AppDateFormatter.iso8601.string(from: Date())); return true }
        catch { logActorError(error, "deleteHoldingTransaction"); return false }
    }

    func deleteHoldingTransactions(accountId: Int, isin: String) async {
        do { try await dbActor.deleteHoldingTransactions(accountId: accountId, isin: isin) } catch { logActorError(error, "deleteHoldingTransactions") }
    }

    func synchronizeHoldingFromTransactions(accountId: Int, isin: String) async {
        let now = AppDateFormatter.iso8601.string(from: Date())
        do {
            try await dbActor.synchronizeHoldingFromTransactions(
                accountId: accountId,
                isin: isin,
                now: now
            )
        } catch {
            logActorError(error, "synchronizeHoldingFromTransactions")
        }
    }

    func getAllHoldingTransactions() async -> [HoldingTransaction] {
        do { return try await dbActor.getAllHoldingTransactions() } catch { logActorError(error, "getAllHoldingTransactions"); return [] }
    }

    func getHoldingTransactions(forIsin instrumentIsin: String) async -> [HoldingTransaction] {
        do { return try await dbActor.getHoldingTransactions(forIsin: instrumentIsin) } catch { logActorError(error, "getHoldingTransactions"); return [] }
    }

    func getHoldingTransactions(accountId: Int, isin: String) async -> [HoldingTransaction] {
        do { return try await dbActor.getHoldingTransactions(accountId: accountId, isin: isin) } catch { logActorError(error, "getHoldingTransactions"); return [] }
    }

    func reconcileHoldingTransactions() async {
        let now = AppDateFormatter.iso8601.string(from: Date())
        do {
            try await dbActor.reconcileHoldingTransactions(now: now, today: AppDateFormatter.todayString)
        } catch {
            logActorError(error, "reconcileHoldingTransactions")
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
    func getLatestPrices(forIsins instrumentIsins: [String]) async -> [Price] { [] }
    func getLastInstrumentUpdateDate() async -> String? { nil }
    func getPrice(forIsin instrumentIsin: String, date targetDate: String) async -> Price? { nil }
    func getPriceHistory(forIsin instrumentIsin: String) async -> [Price] { [] }
    func getPriceHistory(forIsins instrumentIsins: [String]) async -> [Price] { [] }
    func getPriceOnOrBefore(forIsin instrumentIsin: String, date targetDate: String) async -> Price? { nil }
    func getPriceBefore(forIsin instrumentIsin: String, date targetDate: String) async -> Price? { nil }
    func getEarliestPrice(forIsin instrumentIsin: String) async -> Price? { nil }
    
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
    func addHoldingTransaction(accountId: Int, isin: String, date: String, quantityDelta: Double, unitPrice: Double?, kind: HoldingTransactionKind? = nil, fees: Double? = nil, note: String? = nil) async {}
    func updateHoldingTransaction(_ transaction: HoldingTransaction) async {}
    func deleteHoldingTransaction(id: Int) async {}
    func deleteHoldingTransactions(accountId: Int, isin: String) async {}
    func synchronizeHoldingFromTransactions(accountId: Int, isin: String) async {}
    func getAllHoldingTransactions() async -> [HoldingTransaction] { [] }
    func getHoldingTransactions(forIsin instrumentIsin: String) async -> [HoldingTransaction] { [] }
    func getHoldingTransactions(accountId: Int, isin: String) async -> [HoldingTransaction] { [] }
    func reconcileHoldingTransactions() async {}
    
    func getDatabasePath() -> String {
        #if os(iOS)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return documentsURL.appendingPathComponent("PortfolioData/stocks.db").path
        #else
        let home = ProcessInfo.processInfo.environment["HOME"] ?? FileManager.default.homeDirectoryForCurrentUser.path
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport.appendingPathComponent("Portfolio/data/stocks.db").path
        #endif
    }
}
#endif
