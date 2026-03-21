import Foundation
import os.log

// MARK: - App Logger
/// Unified logging for the app. Use instead of `print()` for errors and diagnostics.
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.portfolio.app"
    
    static let database = Logger(subsystem: subsystem, category: "database")
    static let marketData = Logger(subsystem: subsystem, category: "marketData")
    static let backgroundTask = Logger(subsystem: subsystem, category: "backgroundTask")
    static let scheduler = Logger(subsystem: subsystem, category: "scheduler")
    static let general = Logger(subsystem: subsystem, category: "general")
    
    static func databaseLog(_ message: String, isError: Bool = false) {
        if isError {
            database.error("\(message, privacy: .public)")
        } else {
            database.info("\(message, privacy: .public)")
        }
    }
    
    static func marketDataLog(_ message: String, isError: Bool = false) {
        if isError {
            marketData.error("\(message, privacy: .public)")
        } else {
            marketData.debug("\(message, privacy: .public)")
        }
    }
    
    static func backgroundTaskLog(_ message: String, isError: Bool = false) {
        if isError {
            backgroundTask.error("\(message, privacy: .public)")
        } else {
            backgroundTask.info("\(message, privacy: .public)")
        }
    }
    
    static func schedulerLog(_ message: String) {
        scheduler.info("\(message, privacy: .public)")
    }
}
