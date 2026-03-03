import Testing
import Foundation
@testable import PortfolioCore

@Suite("Models")
struct ModelsTests {

    // MARK: - Instrument

    @Test("displayName returns name when available")
    func instrumentDisplayNameWithName() {
        let inst = Instrument(isin: "FR0000000001", ticker: "TKR", name: "My Fund", currency: "EUR", quadrantId: nil)
        #expect(inst.displayName == "My Fund")
    }

    @Test("displayName falls back to ticker when name is nil")
    func instrumentDisplayNameFallbackTicker() {
        let inst = Instrument(isin: "FR0000000001", ticker: "TKR", name: nil, currency: "EUR", quadrantId: nil)
        #expect(inst.displayName == "TKR")
    }

    @Test("displayName falls back to ISIN when name and ticker are nil")
    func instrumentDisplayNameFallbackIsin() {
        let inst = Instrument(isin: "FR0000000001", ticker: nil, name: nil, currency: nil, quadrantId: nil)
        #expect(inst.displayName == "FR0000000001")
    }

    @Test("displayName appends Vera Silver suffix for GECKO coin")
    func instrumentDisplayNameGecko() {
        let inst = Instrument(isin: "COIN:GECKO_SILVER_1OZ", ticker: nil, name: "Gecko Silver", currency: "EUR", quadrantId: nil)
        #expect(inst.displayName == "Gecko Silver (est. Vera Silver 1 oz)")
    }

    @Test("Instrument id is isin")
    func instrumentId() {
        let inst = Instrument(isin: "US1234567890", ticker: nil, name: nil, currency: nil, quadrantId: nil)
        #expect(inst.id == "US1234567890")
    }

    // MARK: - BankAccount

    @Test("BankAccount displayName combines bank and account")
    func bankAccountDisplayName() {
        let account = BankAccount(id: 1, bankName: "BNP", accountName: "PEA")
        #expect(account.displayName == "BNP - PEA")
    }

    // MARK: - HoldingEditItem

    @Test("HoldingEditItem id combines accountId and isin")
    func holdingEditItemId() {
        let item = HoldingEditItem(accountId: 42, isin: "FR0000000001")
        #expect(item.id == "42-FR0000000001")
    }

    // MARK: - HoldingDetail

    @Test("currentValue multiplies quantity by price")
    func holdingDetailCurrentValue() {
        let detail = makeHoldingDetail(quantity: 10, currentPrice: 50.0)
        #expect(detail.currentValue == 500.0)
    }

    @Test("currentValue returns nil when price is nil")
    func holdingDetailCurrentValueNil() {
        let detail = makeHoldingDetail(quantity: 10, currentPrice: nil)
        #expect(detail.currentValue == nil)
    }

    @Test("changePercentEUR computes correct percentage")
    func holdingDetailChangePercent() {
        let detail = makeHoldingDetail(currentValueEUR: 1100, previousValueEUR: 1000)
        #expect(detail.changePercentEUR == 10.0)
    }

    @Test("changePercentEUR returns nil when previous is zero")
    func holdingDetailChangePercentZeroPrevious() {
        let detail = makeHoldingDetail(currentValueEUR: 1000, previousValueEUR: 0)
        #expect(detail.changePercentEUR == nil)
    }

    @Test("changePercentEUR returns nil when previous is nil")
    func holdingDetailChangePercentNilPrevious() {
        let detail = makeHoldingDetail(currentValueEUR: 1000, previousValueEUR: nil)
        #expect(detail.changePercentEUR == nil)
    }

    @Test("changePercentEUR returns nil when current is nil")
    func holdingDetailChangePercentNilCurrent() {
        let detail = makeHoldingDetail(currentValueEUR: nil, previousValueEUR: 1000)
        #expect(detail.changePercentEUR == nil)
    }

    @Test("changePercentEUR handles negative change")
    func holdingDetailNegativeChange() {
        let detail = makeHoldingDetail(currentValueEUR: 900, previousValueEUR: 1000)
        #expect(detail.changePercentEUR == -10.0)
    }

    // MARK: - QuadrantReportItem

    @Test("totalValueEUR sums all EUR-converted current values")
    func quadrantReportTotalValueEUR() {
        let holdings = [
            makeHoldingDetail(currentValueEUR: 500, previousValueEUR: 400),
            makeHoldingDetail(currentValueEUR: 300, previousValueEUR: 250)
        ]
        let report = QuadrantReportItem(quadrant: Quadrant(id: 1, name: "Q1"), holdings: holdings)
        #expect(report.totalValueEUR == 800.0)
        #expect(report.totalPreviousValueEUR == 650.0)
    }

    @Test("changePercentEUR returns nil when no previous values")
    func quadrantReportChangePercentNoPrevious() {
        let holdings = [makeHoldingDetail(currentValueEUR: 500, previousValueEUR: nil)]
        let report = QuadrantReportItem(quadrant: nil, holdings: holdings)
        #expect(report.changePercentEUR == nil)
    }

    @Test("changePercentEUR computes portfolio-level change")
    func quadrantReportChangePercent() {
        let holdings = [
            makeHoldingDetail(currentValueEUR: 1100, previousValueEUR: 1000),
            makeHoldingDetail(currentValueEUR: 550, previousValueEUR: 500)
        ]
        let report = QuadrantReportItem(quadrant: nil, holdings: holdings)
        #expect(report.totalValueEUR == 1650.0)
        #expect(report.totalPreviousValueEUR == 1500.0)
        #expect(report.changePercentEUR == 10.0)
    }

    // MARK: - ReportPeriod

    @Test("comparisonDate returns a date in the past for all cases",
          arguments: ReportPeriod.allCases)
    func reportPeriodComparisonDate(period: ReportPeriod) {
        let date = period.comparisonDate
        #expect(date < Date())
    }

    @Test("oneDay returns approximately yesterday")
    func reportPeriodOneDay() {
        let expected = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let result = ReportPeriod.oneDay.comparisonDate
        let diff = abs(result.timeIntervalSince(expected))
        #expect(diff < 1.0)
    }

    @Test("oneWeek returns approximately 7 days ago")
    func reportPeriodOneWeek() {
        let expected = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let result = ReportPeriod.oneWeek.comparisonDate
        let diff = abs(result.timeIntervalSince(expected))
        #expect(diff < 1.0)
    }

    @Test("yearToDate returns January 1st of current year")
    func reportPeriodYearToDate() {
        let result = ReportPeriod.yearToDate.comparisonDate
        let components = Calendar.current.dateComponents([.month, .day], from: result)
        #expect(components.month == 1)
        #expect(components.day == 1)
    }

    // MARK: - Helpers

    private func makeHoldingDetail(
        quantity: Double = 1,
        currentPrice: Double? = 100,
        previousPrice: Double? = 90,
        currentValueEUR: Double? = nil,
        previousValueEUR: Double? = nil
    ) -> HoldingDetail {
        HoldingDetail(
            accountId: 1,
            isin: "TEST",
            instrumentName: "Test",
            instrumentCurrency: "EUR",
            ticker: nil,
            quantity: quantity,
            currentPrice: currentPrice,
            previousPrice: previousPrice,
            priceDate: "2025-01-01",
            currentValueEUR: currentValueEUR,
            previousValueEUR: previousValueEUR
        )
    }
}
