import Foundation

/// Shared, cached date formatters used across the app.
/// DateFormatter is expensive to create — reuse these static instances.
public enum AppDateFormatter {
    /// Format: "yyyy-MM-dd"
    public static let yearMonthDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Format: "yyyy-MM-dd HH:mm:ss"
    public static let yearMonthDayTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    /// Format: "MMM d, yyyy"
    public static let mediumDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    /// ISO 8601 formatter that outputs "yyyy-MM-dd..." — use for today's date string.
    public static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()

    /// Returns today's date as "yyyy-MM-dd".
    public static var todayString: String {
        yearMonthDay.string(from: Date())
    }
}
