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
