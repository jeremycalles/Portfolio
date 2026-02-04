import Foundation
import BackgroundTasks
import UIKit

// MARK: - Background Task Log Entry
struct BackgroundTaskLogEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let message: String
    let isError: Bool
    
    init(message: String, isError: Bool = false) {
        self.id = UUID()
        self.timestamp = Date()
        self.message = message
        self.isError = isError
    }
}

// MARK: - Background Task Manager
class BackgroundTaskManager: ObservableObject {
    static let shared = BackgroundTaskManager()
    
    static let refreshTaskIdentifier = "com.portfolio.app.refresh"
    
    // Minimum interval between background refreshes (3 hours)
    private let minimumRefreshInterval: TimeInterval = 3 * 60 * 60
    
    // Log storage
    @Published private(set) var lastRefreshLogs: [BackgroundTaskLogEntry] = []
    private let logsKey = "backgroundRefreshLogs"
    
    private init() {
        loadLogs()
    }
    
    // MARK: - Logging
    
    private func log(_ message: String, isError: Bool = false) {
        let entry = BackgroundTaskLogEntry(message: message, isError: isError)
        lastRefreshLogs.append(entry)
        print("[BackgroundTask] \(message)")
    }
    
    private func clearLogs() {
        lastRefreshLogs.removeAll()
    }
    
    private func saveLogs() {
        if let encoded = try? JSONEncoder().encode(lastRefreshLogs) {
            UserDefaults.standard.set(encoded, forKey: logsKey)
        }
    }
    
    private func loadLogs() {
        if let data = UserDefaults.standard.data(forKey: logsKey),
           let decoded = try? JSONDecoder().decode([BackgroundTaskLogEntry].self, from: data) {
            lastRefreshLogs = decoded
        }
    }
    
    func getLogsText() -> String {
        if lastRefreshLogs.isEmpty {
            return "No background refresh logs available yet.\n\nLogs will appear here after the first background refresh occurs."
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        return lastRefreshLogs.map { entry in
            let prefix = entry.isError ? "❌" : "✓"
            return "\(prefix) [\(dateFormatter.string(from: entry.timestamp))] \(entry.message)"
        }.joined(separator: "\n")
    }
    
    // MARK: - Task Registration
    
    /// Call this in application didFinishLaunching
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshTaskIdentifier,
            using: nil
        ) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        
        print("[BackgroundTask] Registered background refresh task")
    }
    
    // MARK: - Task Scheduling
    
    /// Schedule the next background refresh
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
        
        // Schedule for 3 hours from now (iOS may delay further based on system conditions)
        request.earliestBeginDate = Date(timeIntervalSinceNow: minimumRefreshInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("[BackgroundTask] Scheduled refresh for \(request.earliestBeginDate?.description ?? "unknown")")
        } catch {
            print("[BackgroundTask] Failed to schedule refresh: \(error.localizedDescription)")
        }
    }
    
    /// Cancel any pending background refresh tasks
    func cancelPendingRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshTaskIdentifier)
        print("[BackgroundTask] Cancelled pending refresh tasks")
    }
    
    // MARK: - Task Handling
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        Task { @MainActor in
            self.clearLogs()
            self.log("Starting background refresh")
        }
        
        // Schedule the next refresh immediately (so it's queued for next time)
        scheduleAppRefresh()
        
        let refreshTask = Task { @MainActor in
            let success = await self.performPriceRefresh()
            task.setTaskCompleted(success: success)
            self.log("Background refresh completed with success: \(success)")
            self.saveLogs()
        }
        
        task.expirationHandler = {
            Task { @MainActor in
                self.log("Task expired by iOS, cancelling", isError: true)
                self.saveLogs()
            }
            refreshTask.cancel()
        }
    }
    
    // MARK: - Price Refresh Logic
    
    @MainActor
    private func performPriceRefresh() async -> Bool {
        var successCount = 0
        var failureCount = 0
        
        // Get the shared view model or database service
        let instruments = DatabaseService.shared.getAllInstruments()
        
        guard !instruments.isEmpty else {
            log("No instruments to refresh")
            return true
        }
        
        log("Found \(instruments.count) instruments to refresh")
        
        // Update prices for all instruments
        for instrument in instruments {
            let displayName = instrument.name ?? instrument.ticker ?? instrument.isin
            
            let result = await MarketDataService.shared.fetchData(isin: instrument.isin, ticker: instrument.ticker)
            
            if let price = result.value {
                let newPrice = Price(
                    isin: instrument.isin,
                    date: result.date,
                    value: price,
                    currency: result.currency
                )
                DatabaseService.shared.addPrice(newPrice)
                
                // Update instrument info if available (but NOT currency - that should stay as originally set)
                if result.name != nil || result.ticker != nil {
                    var updatedInstrument = instrument
                    if let name = result.name { updatedInstrument.name = name }
                    if let ticker = result.ticker { updatedInstrument.ticker = ticker }
                    // Do NOT update currency here - FT may return wrong share class currency
                    DatabaseService.shared.addOrUpdateInstrument(updatedInstrument)
                }
                
                log("\(displayName): \(String(format: "%.2f", price)) \(result.currency ?? "")")
                successCount += 1
            } else {
                log("\(displayName): Failed to fetch price", isError: true)
                failureCount += 1
            }
            
            // Small delay to avoid rate limiting
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        // Save last refresh time
        UserDefaults.standard.set(Date(), forKey: "lastBackgroundRefresh")
        
        // Fetch and store S&P 500 history in background (does not block refresh completion)
        Task.detached(priority: .utility) {
            let prices = await MarketDataService.shared.fetchSP500History(period: "2y", interval: "1d")
            await MainActor.run {
                for price in prices {
                    DatabaseService.shared.addPrice(price)
                }
            }
        }
        
        log("Refresh complete: \(successCount) success, \(failureCount) failed")
        
        return failureCount == 0
    }
    
    // MARK: - Manual Refresh (for testing)
    
    @MainActor
    func performManualRefresh() async {
        clearLogs()
        log("Starting manual refresh")
        let success = await performPriceRefresh()
        log("Manual refresh completed with success: \(success)")
        saveLogs()
    }
}

// MARK: - App Lifecycle Integration
extension BackgroundTaskManager {
    /// Call when app enters background
    func appDidEnterBackground() {
        scheduleAppRefresh()
    }
    
    /// Call when app becomes active
    func appDidBecomeActive() {
        // Optionally check if a refresh is needed
        if shouldRefreshOnForeground() {
            print("[BackgroundTask] App became active, refresh may be needed")
        }
    }
    
    private func shouldRefreshOnForeground() -> Bool {
        guard let lastRefresh = UserDefaults.standard.object(forKey: "lastBackgroundRefresh") as? Date else {
            return true
        }
        
        // If more than 3 hours since last refresh
        return Date().timeIntervalSince(lastRefresh) > minimumRefreshInterval
    }
    
    /// Get time since last refresh for display
    func timeSinceLastRefresh() -> String? {
        guard let lastRefresh = UserDefaults.standard.object(forKey: "lastBackgroundRefresh") as? Date else {
            return nil
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastRefresh, relativeTo: Date())
    }
}
