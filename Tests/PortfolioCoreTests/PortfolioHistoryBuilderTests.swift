import Foundation
import Testing
@testable import PortfolioMultiplatform

@Suite("PortfolioHistoryBuilder")
struct PortfolioHistoryBuilderTests {

    private let aapl: [(date: String, value: Double)] = [
        ("2026-01-02", 100),
        ("2026-01-15", 110),
        ("2026-01-30", 120)
    ]
    private let gold: [(date: String, value: Double)] = [
        ("2026-01-20", 50)
    ]

    @Test("priceOnOrBefore carries the last known price forward")
    func priceCarryForward() {
        #expect(PortfolioHistoryBuilder.priceOnOrBefore(index: aapl, date: "2026-01-01") == nil)
        #expect(PortfolioHistoryBuilder.priceOnOrBefore(index: aapl, date: "2026-01-02") == 100)
        #expect(PortfolioHistoryBuilder.priceOnOrBefore(index: aapl, date: "2026-01-10") == 100)
        #expect(PortfolioHistoryBuilder.priceOnOrBefore(index: aapl, date: "2026-01-15") == 110)
        #expect(PortfolioHistoryBuilder.priceOnOrBefore(index: aapl, date: "2026-02-01") == 120)
    }

    @Test("past days use only lots dated on or before that day")
    func quantityActuallyHeldUsesLotsOnlyBeforeToday() {
        let lots = [(date: "2026-09-24", quantityDelta: 67.4778)]
        let live = 631.6014
        let today = "2026-10-01"
        #expect(PortfolioHistoryBuilder.quantityActuallyHeld(
            transactions: lots, date: "2026-09-20", liveQuantity: live, today: today
        ) == 0)
        #expect(abs(PortfolioHistoryBuilder.quantityActuallyHeld(
            transactions: lots, date: "2026-09-24", liveQuantity: live, today: today
        ) - 67.4778) < 0.000_001)
        #expect(abs(PortfolioHistoryBuilder.quantityActuallyHeld(
            transactions: lots, date: "2026-09-30", liveQuantity: live, today: today
        ) - 67.4778) < 0.000_001)
        // Today also comes from lots so the chart cannot jump when live qty disagrees.
        #expect(abs(PortfolioHistoryBuilder.quantityActuallyHeld(
            transactions: lots, date: today, liveQuantity: live, today: today
        ) - 67.4778) < 0.000_001)
    }

    @Test("no lots contribute nothing on every day including today")
    func quantityActuallyHeldEmptyLots() {
        let live = 631.6014
        let today = "2026-10-01"
        #expect(PortfolioHistoryBuilder.quantityActuallyHeld(
            transactions: [], date: "2026-09-20", liveQuantity: live, today: today
        ) == 0)
        #expect(PortfolioHistoryBuilder.quantityActuallyHeld(
            transactions: [], date: today, liveQuantity: live, today: today
        ) == 0)
        #expect(PortfolioHistoryBuilder.quantityActuallyHeld(
            transactions: [], date: today, liveQuantity: -2, today: today
        ) == 0)
    }

    @Test("a lot that matches the live quantity is zero before its date")
    func quantityActuallyHeldFullLot() {
        let fullLot = [(date: "2026-09-26", quantityDelta: 1644.43)]
        let today = "2026-10-01"
        #expect(PortfolioHistoryBuilder.quantityActuallyHeld(
            transactions: fullLot, date: "2026-09-20", liveQuantity: 1644.43, today: today
        ) == 0)
        #expect(PortfolioHistoryBuilder.quantityActuallyHeld(
            transactions: fullLot, date: "2026-09-26", liveQuantity: 1644.43, today: today
        ) == 1644.43)
        #expect(PortfolioHistoryBuilder.quantityActuallyHeld(
            transactions: fullLot, date: today, liveQuantity: 1644.43, today: today
        ) == 1644.43)
    }

    @Test("a sell changes every day from lots, including today")
    func quantityActuallyHeldSellThenLive() {
        let lots = [
            (date: "2026-09-01", quantityDelta: 10.0),
            (date: "2026-09-15", quantityDelta: -4.0)
        ]
        let today = "2026-10-01"
        #expect(PortfolioHistoryBuilder.quantityActuallyHeld(
            transactions: lots, date: "2026-08-31", liveQuantity: 4, today: today
        ) == 0)
        #expect(PortfolioHistoryBuilder.quantityActuallyHeld(
            transactions: lots, date: "2026-09-10", liveQuantity: 4, today: today
        ) == 10)
        #expect(PortfolioHistoryBuilder.quantityActuallyHeld(
            transactions: lots, date: "2026-09-15", liveQuantity: 4, today: today
        ) == 6)
        #expect(PortfolioHistoryBuilder.quantityActuallyHeld(
            transactions: lots, date: today, liveQuantity: 4, today: today
        ) == 6)
    }

    @Test("chartDates always includes the period start and today")
    func chartDatesIncludesEndpoints() {
        let dates = PortfolioHistoryBuilder.chartDates(
            cutoff: "2026-01-01",
            today: "2026-01-31",
            priceDates: [aapl.map(\.date)]
        )
        #expect(dates.first == "2026-01-01")
        #expect(dates.last == "2026-01-31")
        #expect(dates.contains("2026-01-02"))
        #expect(dates.contains("2026-01-15"))
        #expect(dates.contains("2026-01-30"))
    }

    @Test("chartDates ignores prices outside the window")
    func chartDatesClampsToWindow() {
        let dates = PortfolioHistoryBuilder.chartDates(
            cutoff: "2026-01-10",
            today: "2026-01-20",
            priceDates: [aapl.map(\.date), ["2025-12-01", "2026-02-01"]]
        )
        #expect(dates.first == "2026-01-10")
        #expect(dates.last == "2026-01-20")
        #expect(!dates.contains("2026-01-02"))
        #expect(dates.contains("2026-01-15"))
        #expect(!dates.contains("2025-12-01"))
        #expect(!dates.contains("2026-02-01"))
    }

    @Test("1 week / 1 month / YTD windows produce the expected cutoff strings")
    func reportPeriodCutoffStrings() {
        let formatter = AppDateFormatter.yearMonthDay
        let week = formatter.string(from: ReportPeriod.oneWeek.comparisonDate)
        let month = formatter.string(from: ReportPeriod.oneMonth.comparisonDate)
        let ytd = formatter.string(from: ReportPeriod.yearToDate.comparisonDate)
        let today = AppDateFormatter.todayString

        #expect(week < today)
        #expect(month < week)
        #expect(ytd.hasSuffix("-01-01"))
        #expect(ytd.hasPrefix(String(Calendar.current.component(.year, from: Date()))))
    }

    @Test("series starts at cutoff and percent matches first-to-last")
    func seriesStartsAtCutoffAndPercentMatches() async {
        let holdings = [(isin: "AAPL", quantity: 2.0)]
        let prices = ["AAPL": aapl]
        let dates = PortfolioHistoryBuilder.chartDates(
            cutoff: "2026-01-01",
            today: "2026-01-31",
            priceDates: [aapl.map(\.date)]
        )
        let series = await PortfolioHistoryBuilder.series(
            dates: dates,
            holdings: holdings,
            prices: prices,
            transactionsByIsin: ["AAPL": [(date: "2025-12-01", quantityDelta: 2.0)]],
            today: "2026-01-31"
        ) { _, native, _ in native }

        #expect(series.first?.date == "2026-01-02")
        #expect(series.first?.value == 200)
        #expect(series.last?.date == "2026-01-31")
        #expect(series.last?.value == 240)

        let percent = PortfolioHistoryBuilder.percentChange(from: series.first!.value, to: series.last!.value)
        #expect(percent == 20.0)
    }

    @Test("series omits a holding until its first known price exists")
    func seriesWaitsForFirstPrice() async {
        let holdings = [(isin: "GOLD", quantity: 2.0)]
        let prices = ["GOLD": [(date: "2026-01-20", value: 50.0)]]
        let dates = ["2026-01-01", "2026-01-20", "2026-01-31"]
        let series = await PortfolioHistoryBuilder.series(
            dates: dates,
            holdings: holdings,
            prices: prices,
            transactionsByIsin: ["GOLD": [(date: "2025-12-01", quantityDelta: 2.0)]],
            today: "2026-01-31"
        ) { _, native, _ in native }

        #expect(series.first { $0.date == "2026-01-01" } == nil)
        #expect(series.first { $0.date == "2026-01-20" }?.value == 100)
    }

    @Test("a holding that only appears mid-period does not inflate the start value")
    func lateHoldingDoesNotInflateStart() async {
        let holdings = [
            (isin: "AAPL", quantity: 1.0),
            (isin: "GOLD", quantity: 2.0)
        ]
        let prices = ["AAPL": aapl, "GOLD": gold]
        let dates = PortfolioHistoryBuilder.chartDates(
            cutoff: "2026-01-01",
            today: "2026-01-31",
            priceDates: [aapl.map(\.date), gold.map(\.date)]
        )
        let series = await PortfolioHistoryBuilder.series(
            dates: dates,
            holdings: holdings,
            prices: prices,
            transactionsByIsin: [
                "AAPL": [(date: "2025-12-01", quantityDelta: 1.0)],
                "GOLD": [(date: "2025-12-01", quantityDelta: 2.0)]
            ],
            today: "2026-01-31"
        ) { _, native, _ in native }

        // The aggregate starts only when every active position has a known price.
        #expect(series.first?.date == "2026-01-20")
        #expect(series.first?.value == 210)
        // Jan 31: AAPL 120 + GOLD 100 = 220
        #expect(series.last?.value == 220)
        let percent = PortfolioHistoryBuilder.percentChange(from: series.first!.value, to: series.last!.value)
        #expect(abs((percent ?? 0) - (10.0 / 210.0 * 100.0)) < 0.000_001)
    }

    @Test("missing FX conversion omits that date instead of treating the amount as EUR")
    func missingFxOmitsDate() async {
        let holdings = [(isin: "USD-ETF", quantity: 1.0)]
        let prices = ["USD-ETF": aapl]
        let dates = ["2026-01-02", "2026-01-15"]
        let series = await PortfolioHistoryBuilder.series(
            dates: dates,
            holdings: holdings,
            prices: prices,
            transactionsByIsin: ["USD-ETF": [(date: "2025-12-01", quantityDelta: 1.0)]],
            today: "2026-01-15"
        ) { _, native, date in
            date == "2026-01-02" ? nil : native
        }
        #expect(series.map(\.date) == ["2026-01-15"])
    }

    @Test("chartDates includes transaction dates in the window")
    func chartDatesIncludesTransactions() {
        let dates = PortfolioHistoryBuilder.chartDates(
            cutoff: "2026-01-01",
            today: "2026-01-31",
            priceDates: [aapl.map(\.date)],
            transactionDates: ["2025-12-15", "2026-01-20", "2026-02-01"]
        )
        #expect(dates.contains("2026-01-20"))
        #expect(!dates.contains("2025-12-15"))
        #expect(!dates.contains("2026-02-01"))
    }

    @Test("quantityOnDate is zero before the first buy")
    func quantityZeroBeforeBuy() {
        let lots = [(date: "2026-01-20", quantityDelta: 2.0)]
        #expect(PortfolioHistoryBuilder.quantityOnDate(transactions: lots, date: "2026-01-01", fallbackQuantity: 2) == 0)
        #expect(PortfolioHistoryBuilder.quantityOnDate(transactions: lots, date: "2026-01-20", fallbackQuantity: 2) == 2)
        #expect(PortfolioHistoryBuilder.quantityOnDate(transactions: lots, date: "2026-01-31", fallbackQuantity: 2) == 2)
    }

    @Test("quantityOnDate falls back when there are no lots")
    func quantityFallbackWithoutLots() {
        #expect(PortfolioHistoryBuilder.quantityOnDate(transactions: [], date: "2026-01-01", fallbackQuantity: 5) == 5)
    }

    @Test("a sell reduces quantity after that date")
    func quantityAfterSell() {
        let lots = [
            (date: "2026-01-02", quantityDelta: 3.0),
            (date: "2026-01-15", quantityDelta: -1.0)
        ]
        #expect(PortfolioHistoryBuilder.quantityOnDate(transactions: lots, date: "2026-01-10", fallbackQuantity: 2) == 3)
        #expect(PortfolioHistoryBuilder.quantityOnDate(transactions: lots, date: "2026-01-15", fallbackQuantity: 2) == 2)
        #expect(PortfolioHistoryBuilder.quantityOnDate(transactions: lots, date: "2026-01-31", fallbackQuantity: 2) == 2)
    }

    @Test("series is zero before a buy then marks the position")
    func seriesZeroBeforeBuy() async {
        let holdings = [(isin: "AAPL", quantity: 1.0)]
        let lots = ["AAPL": [(date: "2026-01-15", quantityDelta: 1.0)]]
        let dates = PortfolioHistoryBuilder.chartDates(
            cutoff: "2026-01-01",
            today: "2026-01-31",
            priceDates: [aapl.map(\.date)],
            transactionDates: ["2026-01-15"]
        )
        let series = await PortfolioHistoryBuilder.series(
            dates: dates,
            holdings: holdings,
            prices: ["AAPL": aapl],
            transactionsByIsin: lots,
            today: "2026-01-31"
        ) { _, native, _ in native }

        let start = series.first { $0.date == "2026-01-01" }
        #expect(start?.value == 0)
        let onBuy = series.first { $0.date == "2026-01-15" }
        #expect(onBuy?.value == 110)
        #expect(series.last?.value == 120)
    }

    @Test("holdings with no lots never override the transaction ledger")
    func seriesEmptyLotsStayAtZero() async {
        let holdings = [(isin: "AAPL", quantity: 2.0)]
        let dates = ["2026-01-01", "2026-01-15", "2026-01-31"]
        let series = await PortfolioHistoryBuilder.series(
            dates: dates,
            holdings: holdings,
            prices: ["AAPL": aapl],
            today: "2026-01-31"
        ) { _, native, _ in native }

        #expect(series.first { $0.date == "2026-01-01" }?.value == 0)
        #expect(series.first { $0.date == "2026-01-15" }?.value == 0)
        #expect(series.last?.value == 0)
    }

    @Test("a partial lot does not paint today's remainder onto earlier days")
    func seriesPartialLotDoesNotPaintBackward() async {
        let holdings = [(isin: "AAPL", quantity: 3.0)]
        let lots = ["AAPL": [(date: "2026-01-15", quantityDelta: 1.0)]]
        let dates = ["2026-01-02", "2026-01-15", "2026-01-30", "2026-01-31"]
        let series = await PortfolioHistoryBuilder.series(
            dates: dates,
            holdings: holdings,
            prices: ["AAPL": aapl],
            transactionsByIsin: lots,
            today: "2026-01-31"
        ) { _, native, _ in native }

        #expect(series.first { $0.date == "2026-01-02" }?.value == 0)
        #expect(series.first { $0.date == "2026-01-15" }?.value == 110)
        #expect(series.first { $0.date == "2026-01-30" }?.value == 120)
        #expect(series.last?.value == 120)
    }

    @Test("TWR strips a mid-period buy out of performance")
    func twrDoesNotTreatBuyAsGain() async {
        let holdings = [(isin: "AAPL", quantity: 2.0)]
        let lots = ["AAPL": [
            (date: "2025-12-01", quantityDelta: 1.0),
            (date: "2026-01-20", quantityDelta: 1.0)
        ]]
        let dates = ["2026-01-01", "2026-01-02", "2026-01-15", "2026-01-20", "2026-01-30", "2026-01-31"]
        let nav = await PortfolioHistoryBuilder.series(
            dates: dates,
            holdings: holdings,
            prices: ["AAPL": aapl],
            transactionsByIsin: lots,
            today: "2026-01-31"
        ) { _, native, _ in native }

        #expect(nav.first?.value == 100)
        let onBuy = nav.first { $0.date == "2026-01-20" }?.value
        #expect(onBuy == 220)
        #expect(nav.last?.value == 240)

        let navPercent = PortfolioHistoryBuilder.percentChange(from: nav.first!.value, to: nav.last!.value)
        #expect(navPercent == 140)

        let twr = PortfolioHistoryBuilder.timeWeightedReturn(
            nav: nav,
            cashflows: [(date: "2026-01-20", amountEUR: 110)]
        )
        #expect(twr != nil)
        #expect(abs((twr ?? 0) - 20) < 0.01)
        #expect(twr != navPercent)
    }

    @Test("TWR without cashflows matches first-to-last percent")
    func twrMatchesSimpleWhenNoCashflows() {
        let nav = [
            (date: "2026-01-01", value: 100.0),
            (date: "2026-01-31", value: 120.0)
        ]
        #expect(PortfolioHistoryBuilder.timeWeightedReturn(nav: nav, cashflows: []) == 20)
    }

    @Test("percentChange returns nil when the start value is zero")
    func percentChangeNilOnZero() {
        #expect(PortfolioHistoryBuilder.percentChange(from: 0, to: 50) == nil)
        #expect(PortfolioHistoryBuilder.percentChange(from: 100, to: 90) == -10)
    }
}
