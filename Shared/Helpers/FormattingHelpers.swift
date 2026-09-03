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

func formatCompactCurrency(_ value: Double) -> String {
    if value >= 1_000_000 {
        return String(format: "%.1fM", value / 1_000_000)
    } else if value >= 1_000 {
        return String(format: "%.0fK", value / 1_000)
    } else {
        return String(format: "%.0f", value)
    }
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
