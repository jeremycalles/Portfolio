import Foundation

// MARK: - Currency & Quantity Formatting

func formatCurrency(_ value: Double, currency: String) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = currency
    formatter.maximumFractionDigits = 2
    return formatter.string(from: NSNumber(value: value)) ?? "\(currency) \(value)"
}

func formatQuantity(_ value: Double) -> String {
    if value == floor(value) {
        return String(format: "%.0f", value)
    } else if value * 10 == floor(value * 10) {
        return String(format: "%.1f", value)
    } else {
        return String(format: "%.4f", value)
    }
}

/// Compact amount for axes and ring centers ("13,2 k", "1,2 M").
/// Three significant digits so neighbouring axis ticks stay distinct
/// (the old "%.0fK" printed 13K for 12 500, 13 000 and 13 500).
func formatCompactCurrency(_ value: Double, locale: Locale = .autoupdatingCurrent) -> String {
    value.formatted(.number.notation(.compactName).precision(.significantDigits(1...3)).locale(locale))
}

/// Signed, locale-aware percent from a value in percent units (1.24 → "+1,24 %" in French).
func formatPercentChange(_ percent: Double, fractionDigits: Int = 2, locale: Locale = .autoupdatingCurrent) -> String {
    (percent / 100).formatted(
        .percent
            .precision(.fractionLength(fractionDigits))
            .sign(strategy: .always(includingZero: false))
            .locale(locale)
    )
}

/// Unsigned, locale-aware percent from a value in percent units.
func formatPercent(_ percent: Double, fractionDigits: Int = 2, locale: Locale = .autoupdatingCurrent) -> String {
    (percent / 100).formatted(.percent.precision(.fractionLength(fractionDigits)).locale(locale))
}

// MARK: - Decimal Parsing

/// Converts `value` to EUR. Returns `value` when the currency is EUR or missing.
/// Returns `nil` when a non-EUR currency has no exchange rate — never treat the raw amount as EUR.
enum CurrencyConversion {
    static func euros(value: Double, fromCurrency: String?, rate: Double?) -> Double? {
        guard let currency = fromCurrency?.trimmingCharacters(in: .whitespacesAndNewlines),
              !currency.isEmpty,
              currency.uppercased() != "EUR" else {
            return value
        }
        guard let rate else { return nil }
        return value * rate
    }
}

/// Locale-aware decimal parsing (handles comma or period as decimal separator).
/// Tries current locale first, then fallback replacing comma with period.
func parseDecimal(_ text: String) -> Double? {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = .current
    if let number = formatter.number(from: text) {
        return number.doubleValue
    }
    return Double(text.replacingOccurrences(of: ",", with: "."))
}
