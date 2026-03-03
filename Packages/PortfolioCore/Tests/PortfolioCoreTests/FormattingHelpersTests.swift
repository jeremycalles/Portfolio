import Testing
import Foundation
@testable import PortfolioCore

@Suite("FormattingHelpers")
struct FormattingHelpersTests {

    // MARK: - formatQuantity

    @Test("formatQuantity formats whole numbers without decimals")
    func formatQuantityWholeNumber() {
        #expect(formatQuantity(10.0) == "10")
        #expect(formatQuantity(0.0) == "0")
        #expect(formatQuantity(1000.0) == "1000")
    }

    @Test("formatQuantity formats one-decimal values with 1 digit")
    func formatQuantityOneDecimal() {
        #expect(formatQuantity(10.5) == "10.5")
        #expect(formatQuantity(0.3) == "0.3")
    }

    @Test("formatQuantity formats multi-decimal values with 4 digits")
    func formatQuantityMultiDecimal() {
        #expect(formatQuantity(10.25) == "10.2500")
        #expect(formatQuantity(0.1234) == "0.1234")
        #expect(formatQuantity(1.0001) == "1.0001")
    }

    // MARK: - formatCompactCurrency

    @Test("formatCompactCurrency formats millions with M suffix")
    func formatCompactMillions() {
        #expect(formatCompactCurrency(1_000_000) == "1.0M")
        #expect(formatCompactCurrency(2_500_000) == "2.5M")
    }

    @Test("formatCompactCurrency formats thousands with K suffix")
    func formatCompactThousands() {
        #expect(formatCompactCurrency(1_000) == "1K")
        #expect(formatCompactCurrency(50_000) == "50K")
        #expect(formatCompactCurrency(999_999) == "1000K")
    }

    @Test("formatCompactCurrency formats small values without suffix")
    func formatCompactSmall() {
        #expect(formatCompactCurrency(999) == "999")
        #expect(formatCompactCurrency(0) == "0")
        #expect(formatCompactCurrency(42) == "42")
    }

    // MARK: - parseDecimal

    @Test("parseDecimal parses standard decimal with period")
    func parseDecimalPeriod() {
        let result = parseDecimal("123.45")
        #expect(result != nil)
        #expect(abs(result! - 123.45) < 0.001)
    }

    @Test("parseDecimal parses comma as decimal separator")
    func parseDecimalComma() {
        let result = parseDecimal("123,45")
        #expect(result != nil)
        #expect(abs(result! - 123.45) < 0.001)
    }

    @Test("parseDecimal returns nil for invalid input")
    func parseDecimalInvalid() {
        #expect(parseDecimal("abc") == nil)
        #expect(parseDecimal("") == nil)
    }

    @Test("parseDecimal parses integer strings")
    func parseDecimalInteger() {
        let result = parseDecimal("42")
        #expect(result != nil)
        #expect(result! == 42.0)
    }

    // MARK: - formatCurrency

    @Test("formatCurrency produces a non-empty string")
    func formatCurrencyBasic() {
        let result = formatCurrency(1234.56, currency: "EUR")
        #expect(!result.isEmpty)
    }

    @Test("formatCurrency contains the value digits")
    func formatCurrencyContainsValue() {
        let result = formatCurrency(1234.56, currency: "USD")
        #expect(result.contains("1") && result.contains("234"))
    }

    @Test("formatCurrency handles zero")
    func formatCurrencyZero() {
        let result = formatCurrency(0, currency: "EUR")
        #expect(result.contains("0"))
    }

    @Test("formatCurrency handles negative values")
    func formatCurrencyNegative() {
        let result = formatCurrency(-500.0, currency: "EUR")
        #expect(result.contains("500"))
    }
}
