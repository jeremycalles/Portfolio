import Foundation

/// Shared, cached date formatters used across the app.
/// DateFormatter is expensive to create — reuse these static instances.
enum AppDateFormatter {
    /// Format: "yyyy-MM-dd"
    static let yearMonthDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Format: "yyyy-MM-dd HH:mm:ss"
    static let yearMonthDayTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    /// Format: "MMM d, yyyy"
    static let mediumDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    /// ISO 8601 formatter that outputs "yyyy-MM-dd..." — use for today's date string.
    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()

    /// Localized UI rendering; persisted dates keep their canonical format.
    static func displayDate(_ stored: String) -> String {
        guard let date = yearMonthDay.date(from: stored) else { return stored }
        let locale = Locale(identifier: LanguageManager.shared.currentLanguage.rawValue)
        return date.formatted(.dateTime.day().month(.abbreviated).year().locale(locale))
    }

    /// Returns today's date as "yyyy-MM-dd".
    static var todayString: String {
        yearMonthDay.string(from: Date())
    }
}
