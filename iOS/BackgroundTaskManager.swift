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
    private let logsMaxCount = 200
    
    private init() {
        loadLogs()
    }
    
    // MARK: - Logging
    
    private func log(_ message: String, isError: Bool = false) {
        let entry = BackgroundTaskLogEntry(message: message, isError: isError)
        lastRefreshLogs.append(entry)
        if lastRefreshLogs.count > logsMaxCount {
            lastRefreshLogs.removeFirst(lastRefreshLogs.count - logsMaxCount)
        }
        print("[BackgroundTask] \(message)")
        saveLogs()
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
    
    // MARK: - Task Registration
    
    /// Call this in application didFinishLaunching
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                print("[BackgroundTask] Unexpected task type: \(type(of: task))")
                return
            }
            self?.handleAppRefresh(task: refreshTask)
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
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshTaskIdentifier)
            try BGTaskScheduler.shared.submit(request)
            log("Scheduled refresh for \(request.earliestBeginDate?.description ?? "unknown")")
        } catch {
            log("Failed to schedule refresh: \(error.localizedDescription)", isError: true)
        }
    }
    
    // MARK: - Task Handling
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        Task { @MainActor in
            self.log("Starting background refresh")
        }
        
        // Schedule the next refresh immediately (so it's queued for next time)
        scheduleAppRefresh()
        
        let refreshTask = Task { @MainActor in
            let completed = await self.performPriceRefresh()
            // Report success whenever the attempt finished or made progress.
            // Per-ticker failures must not be reported as task failure — iOS
            // deprioritizes future BGAppRefresh scheduling after false.
            task.setTaskCompleted(success: completed)
            self.log("Background refresh completed with success: \(completed)")
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
        
        let instruments = await DatabaseService.shared.getAllInstruments()
        
        guard !instruments.isEmpty else {
            log("No instruments to refresh")
            return true
        }
        
        log("Found \(instruments.count) instruments to refresh")
        
        for instrument in instruments {
            if Task.isCancelled {
                log("Cancelled with \(successCount) updated, \(failureCount) failed", isError: true)
                if successCount > 0 {
                    UserDefaults.standard.set(Date(), forKey: "lastBackgroundRefresh")
                }
                return successCount > 0
            }
            
            let displayName = instrument.name ?? instrument.ticker ?? instrument.isin
            
            let result = await MarketDataService.shared.fetchData(isin: instrument.isin, ticker: instrument.ticker)
            
            if let price = result.value {
                let newPrice = Price(
                    isin: instrument.isin,
                    date: result.date,
                    value: price,
                    currency: result.currency
                )
                await DatabaseService.shared.addPrice(newPrice)
                
                if result.name != nil || result.ticker != nil {
                    var updatedInstrument = instrument
                    if let name = result.name { updatedInstrument.name = name }
                    if let ticker = result.ticker { updatedInstrument.ticker = ticker }
                    await DatabaseService.shared.addOrUpdateInstrument(updatedInstrument)
                }
                
                log("\(displayName): \(String(format: "%.2f", price)) \(result.currency ?? "")")
                successCount += 1
            } else {
                log("\(displayName): Failed to fetch price", isError: true)
                failureCount += 1
            }
            
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        
        UserDefaults.standard.set(Date(), forKey: "lastBackgroundRefresh")
        log("Refresh complete: \(successCount) success, \(failureCount) failed")
        return true
    }
}

// MARK: - App Lifecycle Integration
extension BackgroundTaskManager {
    /// Call when app enters background
    func appDidEnterBackground() {
        scheduleAppRefresh()
    }
    
    /// Call when app becomes active
    func appDidBecomeActive() -> Bool {
        if shouldRefreshOnForeground() {
            log("App became active and refresh is due")
            return true
        }
        return false
    }
    
    private func shouldRefreshOnForeground() -> Bool {
        guard let lastRefresh = UserDefaults.standard.object(forKey: "lastBackgroundRefresh") as? Date else {
            return true
        }
        
        // If more than 3 hours since last refresh
        return Date().timeIntervalSince(lastRefresh) > minimumRefreshInterval
    }

    /// Time until the next foreground refresh is due. Returns 0 when the app has never refreshed.
    func secondsUntilNextRefresh() -> TimeInterval {
        guard let lastRefresh = UserDefaults.standard.object(forKey: "lastBackgroundRefresh") as? Date else {
            return 0
        }

        let elapsed = Date().timeIntervalSince(lastRefresh)
        return max(0, minimumRefreshInterval - elapsed)
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
