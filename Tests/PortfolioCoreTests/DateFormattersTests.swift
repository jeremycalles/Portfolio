import Testing
import Foundation
@testable import PortfolioMultiplatform

@Suite("DateFormatters")
struct DateFormattersTests {

    @Test("yearMonthDay round-trips a date correctly")
    func yearMonthDayRoundTrip() {
        let dateString = "2025-06-15"
        let date = AppDateFormatter.yearMonthDay.date(from: dateString)
        #expect(date != nil)
        let result = AppDateFormatter.yearMonthDay.string(from: date!)
        #expect(result == dateString)
    }

    @Test("yearMonthDayTime parses datetime string")
    func yearMonthDayTimeParse() {
        let dateString = "2025-06-15 14:30:00"
        let date = AppDateFormatter.yearMonthDayTime.date(from: dateString)
        #expect(date != nil)
    }

    @Test("mediumDate formats correctly")
    func mediumDateFormat() {
        let date = AppDateFormatter.yearMonthDay.date(from: "2025-01-15")!
        let result = AppDateFormatter.mediumDate.string(from: date)
        #expect(result.contains("15"))
        #expect(result.contains("2025"))
    }

    @Test("todayString returns a yyyy-MM-dd formatted string")
    func todayStringFormat() {
        let today = AppDateFormatter.todayString
        #expect(today.count == 10)
        #expect(today.contains("-"))
        let parsed = AppDateFormatter.yearMonthDay.date(from: today)
        #expect(parsed != nil)
    }

    @Test("todayString matches the current date")
    func todayStringMatchesNow() {
        let today = AppDateFormatter.todayString
        let expected = AppDateFormatter.yearMonthDay.string(from: Date())
        #expect(today == expected)
    }

    @Test("iso8601 formatter produces valid output")
    func iso8601Format() {
        let result = AppDateFormatter.iso8601.string(from: Date())
        #expect(!result.isEmpty)
        #expect(result.contains("T"))
    }
}
