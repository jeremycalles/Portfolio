import Foundation
import Testing
@testable import PortfolioMultiplatform

@Suite("PortfolioAnalytics")
struct PortfolioAnalyticsTests {

    @Test("invested capital is a step series of cashflows")
    func investedCapitalSteps() {
        let dates = ["2026-01-01", "2026-01-10", "2026-01-20"].compactMap {
            AppDateFormatter.yearMonthDay.date(from: $0)
        }
        let cashflows = [
            PortfolioCashflow(date: "2026-01-01", amountEUR: 1000),
            PortfolioCashflow(date: "2026-01-15", amountEUR: 500)
        ]
        let series = PortfolioAnalytics.investedCapitalSeries(dates: dates, cashflows: cashflows)
        #expect(series.map(\.value) == [1000, 1000, 1500])
    }

    @Test("benchmark phantoms reinvest the same cashflows")
    func phantomBenchmarkTracksFlows() {
        let portfolio = [
            (date: AppDateFormatter.yearMonthDay.date(from: "2026-01-01")!, value: 100.0),
            (date: AppDateFormatter.yearMonthDay.date(from: "2026-01-10")!, value: 220.0),
            (date: AppDateFormatter.yearMonthDay.date(from: "2026-01-20")!, value: 240.0)
        ]
        let benchmark = [
            (date: "2026-01-01", value: 10.0),
            (date: "2026-01-10", value: 11.0),
            (date: "2026-01-20", value: 12.0)
        ]
        let cashflows = [PortfolioCashflow(date: "2026-01-10", amountEUR: 110)]
        let series = PortfolioAnalytics.benchmarkSeries(
            portfolio: portfolio,
            benchmark: benchmark,
            cashflows: cashflows
        )
        // Start: 100 / 10 = 10 units. On Jan 10 add 110/11 = 10 units → 20 units * 11 = 220
        // Jan 20: 20 * 12 = 240
        #expect(series.count == 3)
        #expect(abs(series[0].value - 100) < 0.01)
        #expect(abs(series[1].value - 220) < 0.01)
        #expect(abs(series[2].value - 240) < 0.01)
    }

    @Test("rebased percent starts at zero")
    func rebasedPercent() {
        let series = [
            (date: Date(), value: 100.0),
            (date: Date().addingTimeInterval(86400), value: 110.0)
        ]
        let rebased = PortfolioAnalytics.rebasedPercent(series)
        #expect(abs((rebased.first?.value ?? 1)) < 0.000_001)
        #expect(abs((rebased.last?.value ?? 0) - 10) < 0.000_001)
    }
}
