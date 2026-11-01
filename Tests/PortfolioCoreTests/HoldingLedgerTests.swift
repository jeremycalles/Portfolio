import Foundation
import Testing
@testable import PortfolioMultiplatform

@Suite("HoldingLedger")
struct HoldingLedgerTests {

    private func tx(
        id: Int? = nil,
        date: String,
        delta: Double,
        kind: HoldingTransactionKind,
        unitPrice: Double? = nil,
        fees: Double? = nil
    ) -> HoldingTransaction {
        HoldingTransaction(
            id: id,
            accountId: 1,
            isin: "AAPL",
            date: date,
            quantityDelta: delta,
            unitPrice: unitPrice,
            createdAt: nil,
            kind: kind,
            fees: fees,
            note: nil
        )
    }

    @Test("quantity is the chronological sum of lots")
    func quantityFromLots() {
        let lots = [
            tx(date: "2026-01-01", delta: 10, kind: .buy),
            tx(date: "2026-01-15", delta: -4, kind: .sell),
            tx(date: "2026-02-01", delta: 2, kind: .adjustment)
        ]
        #expect(HoldingLedger.quantity(on: "2025-12-31", transactions: lots) == 0)
        #expect(HoldingLedger.quantity(on: "2026-01-10", transactions: lots) == 10)
        #expect(HoldingLedger.quantity(on: "2026-01-15", transactions: lots) == 6)
        #expect(HoldingLedger.quantity(transactions: lots) == 8)
    }

    @Test("sells cannot exceed quantity held on that date")
    func rejectsOversell() {
        let existing = [tx(id: 1, date: "2026-01-01", delta: 5, kind: .buy)]
        #expect(throws: HoldingLedgerValidationError.insufficientQuantity(available: 5)) {
            try HoldingLedger.validate(
                kind: .sell,
                quantity: 6,
                date: "2026-01-10",
                today: "2026-01-31",
                existing: existing
            )
        }
    }

    @Test("future dates and zero quantity are rejected")
    func rejectsInvalidInputs() {
        #expect(throws: HoldingLedgerValidationError.futureDate) {
            try HoldingLedger.validate(
                kind: .buy,
                quantity: 1,
                date: "2099-01-01",
                today: "2026-01-31",
                existing: []
            )
        }
        #expect(throws: HoldingLedgerValidationError.invalidQuantity) {
            try HoldingLedger.validate(
                kind: .buy,
                quantity: 0,
                date: "2026-01-01",
                today: "2026-01-31",
                existing: []
            )
        }
    }

    @Test("average cost and realized P&L include fees")
    func averageCostAndRealizedPnL() {
        let lots = [
            tx(date: "2026-01-01", delta: 10, kind: .buy, unitPrice: 100, fees: 10),
            tx(date: "2026-02-01", delta: -4, kind: .sell, unitPrice: 120, fees: 2)
        ]
        let summary = HoldingLedger.summary(transactions: lots)
        // Buy cost = 10*100 + 10 = 1010 → average 101
        // Sell removes 4*101 = 404 cost, proceeds 4*120 - 2 = 478 → realized 74
        #expect(abs(summary.quantity - 6) < 0.000_001)
        #expect(abs((summary.averageCost ?? 0) - 101) < 0.000_001)
        #expect(abs(summary.realizedProfitLoss - 74) < 0.000_001)
        #expect(abs((summary.unrealizedProfitLoss(currentUnitPrice: 130) ?? 0) - (6 * 130 - 606)) < 0.000_001)
    }

    @Test("backfill window grows with the oldest lot")
    func backfillParameters() {
        let today = AppDateFormatter.yearMonthDay.date(from: "2026-10-01")!
        let short = HoldingLedger.backfillParameters(oldestDate: "2026-09-20", today: today)
        #expect(short.period == "3mo")
        let year = HoldingLedger.backfillParameters(oldestDate: "2025-12-01", today: today)
        #expect(year.period == "1y")
        let multi = HoldingLedger.backfillParameters(oldestDate: "2022-01-01", today: today)
        #expect(multi.period == "5y")
    }

    @Test("history quantity never jumps to live qty on today when lots disagree")
    func noLastDayJump() {
        let lots = [(date: "2026-09-01", quantityDelta: 10.0)]
        let today = "2026-10-01"
        let past = PortfolioHistoryBuilder.quantityActuallyHeld(
            transactions: lots, date: "2026-09-15", liveQuantity: 50, today: today
        )
        let onToday = PortfolioHistoryBuilder.quantityActuallyHeld(
            transactions: lots, date: today, liveQuantity: 50, today: today
        )
        #expect(past == 10)
        #expect(onToday == 10)
    }
}

#if canImport(SQLite)
@Suite("Local save and restore safety")
struct LocalStorageSafetyTests {
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test("Restore replaces the portfolio and keeps a readable recovery snapshot")
    func restoreRoundTrip() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("live.db").path
        let live = DatabaseActor(path: path)
        let source = DatabaseActor(path: directory.appendingPathComponent("source.db").path)
        try await live.addOrUpdateInstrument(Instrument(isin: "ORIGINAL", ticker: nil, name: "Original", currency: "EUR", quadrantId: nil))
        try await source.addOrUpdateInstrument(Instrument(isin: "IMPORTED", ticker: nil, name: "Imported", currency: "EUR", quadrantId: nil))
        let snapshot = directory.appendingPathComponent("backup.db")
        try await source.exportSnapshot(to: snapshot)
        try await live.restoreSnapshot(from: snapshot)
        #expect(try await live.getAllInstruments().map(\.isin) == ["IMPORTED"])
        let recovery = DatabaseActor(path: path + ".recovery")
        #expect(try await recovery.getAllInstruments().map(\.isin) == ["ORIGINAL"])
        await recovery.closeConnection()
        await source.closeConnection()
        await live.closeConnection()
    }

    @Test("Invalid backup never replaces the current data")
    func invalidBackupPreservesOriginal() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let live = DatabaseActor(path: directory.appendingPathComponent("live.db").path)
        try await live.addOrUpdateInstrument(Instrument(isin: "ORIGINAL", ticker: nil, name: nil, currency: "EUR", quadrantId: nil))
        let invalid = directory.appendingPathComponent("invalid.db")
        try Data("not a SQLite backup".utf8).write(to: invalid)
        do {
            try await live.restoreSnapshot(from: invalid)
            Issue.record("An invalid backup must be rejected")
        } catch { }
        #expect(try await live.getAllInstruments().map(\.isin) == ["ORIGINAL"])
        await live.closeConnection()
    }

    @Test("A failed operation rolls back both the ledger and current quantity")
    func atomicTransactionSave() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let db = DatabaseActor(path: directory.appendingPathComponent("live.db").path)
        _ = try await db.addBankAccount(bank: "Test bank", account: "Test account")
        let account = try #require(try await db.getAllBankAccounts().first)
        try await db.addOrUpdateInstrument(Instrument(isin: "TEST", ticker: nil, name: nil, currency: "EUR", quadrantId: nil))
        let buy = HoldingTransaction(id: nil, accountId: account.id, isin: "TEST", date: "2026-01-01", quantityDelta: 10, unitPrice: 5, createdAt: nil, kind: .buy)
        try await db.saveTransaction(buy, now: "2026-01-01", updating: false)
        let sell = HoldingTransaction(id: nil, accountId: account.id, isin: "TEST", date: "2026-01-02", quantityDelta: -20, unitPrice: 5, createdAt: nil, kind: .sell)
        do {
            try await db.saveTransaction(sell, now: "2026-01-02", updating: false)
            Issue.record("A sale exceeding the holding must fail")
        } catch { }
        #expect(try await db.getHoldingTransactions(accountId: account.id, isin: "TEST").count == 1)
        #expect(try await db.getAllHoldings().first?.quantity == 10)
        await db.closeConnection()
    }

    @Test("Editing a price date inserts the new quote before removing the old one")
    func priceReplacement() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let db = DatabaseActor(path: directory.appendingPathComponent("live.db").path)
        try await db.savePrice(Price(id: nil, isin: "TEST", date: "2026-01-01", value: 10, currency: "EUR"), replacingDate: nil)
        do {
            try await db.savePrice(Price(id: nil, isin: "TEST", date: "2026-01-02", value: .nan, currency: "EUR"), replacingDate: "2026-01-01")
            Issue.record("An invalid quote must fail")
        } catch { }
        #expect(try await db.getPriceHistory(forIsin: "TEST").map(\.date) == ["2026-01-01"])
        try await db.savePrice(Price(id: nil, isin: "TEST", date: "2026-01-02", value: 12, currency: "EUR"), replacingDate: "2026-01-01")
        #expect(try await db.getPriceHistory(forIsin: "TEST").map(\.date) == ["2026-01-02"])
        await db.closeConnection()
    }
}
#endif

#if canImport(SQLite)
import SQLite

/// Fixture SQL stays on an actor, and only touches each test's temporary directory.
private actor BackupFixture {
    private let connection: Connection
    init(path: String) throws { connection = try Connection(path) }
    func run(_ sql: String) throws { try connection.run(sql) }
}

@Suite("Backup compatibility")
struct BackupCompatibilityTests {
    @Test("A valid SQLite file from another app is rejected")
    func unrelatedSchema() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("unrelated.db")
        let source = try BackupFixture(path: sourceURL.path)
        try await source.run("CREATE TABLE unrelated (id INTEGER)")
        let db = DatabaseActor(path: directory.appendingPathComponent("live.db").path)
        try await db.addOrUpdateInstrument(Instrument(isin: "ORIGINAL", ticker: nil, name: nil, currency: "EUR", quadrantId: nil))
        do {
            try await db.restoreSnapshot(from: sourceURL)
            Issue.record("An unrelated SQLite database must be rejected")
        } catch { }
        #expect(try await db.getAllInstruments().map(\.isin) == ["ORIGINAL"])
        await db.closeConnection()
    }

    @Test("An export contains committed WAL changes")
    func exportIncludesWAL() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourcePath = directory.appendingPathComponent("source.db").path
        let source = DatabaseActor(path: sourcePath)
        _ = try await source.getAllInstruments()
        let writer = try BackupFixture(path: sourcePath)
        try await writer.run("PRAGMA journal_mode=WAL")
        try await writer.run("PRAGMA wal_autocheckpoint=0")
        try await writer.run("INSERT INTO instruments (isin, currency) VALUES ('WAL-ONLY', 'EUR')")
        let exportedURL = directory.appendingPathComponent("snapshot.db")
        try await source.exportSnapshot(to: exportedURL)
        let exported = DatabaseActor(path: exportedURL.path)
        #expect(try await exported.getAllInstruments().map(\.isin) == ["WAL-ONLY"])
        await exported.closeConnection()
        await source.closeConnection()
    }

    @Test("Restore migrates legacy transaction metadata before replacing live data")
    func legacyLedger() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourcePath = directory.appendingPathComponent("legacy.db").path
        let source = DatabaseActor(path: sourcePath)
        _ = try await source.getAllInstruments()
        await source.closeConnection()
        let fixture = try BackupFixture(path: sourcePath)
        try await fixture.run("DROP TABLE holding_transactions")
        try await fixture.run("CREATE TABLE holding_transactions (id INTEGER PRIMARY KEY, account_id INTEGER NOT NULL, isin TEXT NOT NULL, date TEXT NOT NULL, quantity_delta REAL NOT NULL, unit_price REAL, created_at TEXT)")
        try await fixture.run("INSERT INTO holding_transactions VALUES (1, 1, 'LEGACY', '2026-01-01', 10, 5, NULL)")
        let live = DatabaseActor(path: directory.appendingPathComponent("live.db").path)
        try await live.restoreSnapshot(from: URL(fileURLWithPath: sourcePath))
        let transaction = try #require(try await live.getAllHoldingTransactions().first)
        #expect(transaction.quantityDelta == 10)
        #expect(transaction.kind == .opening)
        #expect(transaction.fees == nil)
        await live.closeConnection()
    }
}
#endif
