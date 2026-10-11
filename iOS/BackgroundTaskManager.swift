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
    /// Retry soon after a run that did not finish, but never ask for less than this.
    private let minimumRequestLead: TimeInterval = 15 * 60
    /// BGAppRefresh gets about 30 seconds. Stop starting new batches after this.
    private let backgroundBudget: TimeInterval = 20
    
    // Log storage
    @Published private(set) var lastRefreshLogs: [BackgroundTaskLogEntry] = []
    private let logsKey = "backgroundRefreshLogs"
    private let logsMaxCount = 200
    /// Removed: the request date is now derived from `lastBackgroundRefresh`.
    private let legacyScheduledRefreshDateKey = "scheduledBackgroundRefreshDate"
    static let lastRunOutcomeKey = "backgroundLastRunOutcome"
    static let lastRunDateKey = "backgroundLastRunDate"
    
    /// Result of the last background attempt, shown in Settings.
    enum RunOutcome: String {
        case complete, partial, expired
    }
    
    private init() {
        loadLogs()
        UserDefaults.standard.removeObject(forKey: legacyScheduledRefreshDateKey)
    }
    
    // MARK: - Logging
    
    /// Appends to the in-memory log. Call `saveLogs()` once the run is over;
    /// encoding 200 entries per line ate into the background budget.
    private func log(_ message: String, isError: Bool = false) {
        let entry = BackgroundTaskLogEntry(message: message, isError: isError)
        lastRefreshLogs.append(entry)
        if lastRefreshLogs.count > logsMaxCount {
            lastRefreshLogs.removeFirst(lastRefreshLogs.count - logsMaxCount)
        }
        AppLogger.backgroundTaskLog(message, isError: isError)
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
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleAppRefresh(task: refreshTask)
        }
    }
    
    // MARK: - Task Scheduling
    
    /// Schedule the next background refresh.
    /// The begin date comes from the last finished refresh, not from "now", so
    /// submitting again on every launch or background transition asks for the same
    /// time instead of pushing it three hours later. An update or reboot can drop a
    /// queued request; resubmitting each time puts it back.
    func scheduleAppRefresh() {
        let now = Date()
        let lastRefresh = UserDefaults.standard.object(forKey: "lastBackgroundRefresh") as? Date
        let due = lastRefresh.map { $0.addingTimeInterval(minimumRefreshInterval) } ?? now
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
        request.earliestBeginDate = max(due, now.addingTimeInterval(minimumRequestLead))
        do {
            try BGTaskScheduler.shared.submit(request)
            let when = request.earliestBeginDate?.description ?? "unknown"
            Task { @MainActor in
                self.log("Scheduled refresh for \(when). Background refresh status: \(Self.refreshStatusDescription)")
                self.saveLogs()
            }
        } catch {
            let message = error.localizedDescription
            Task { @MainActor in
                self.log("Failed to schedule refresh: \(message). Background refresh status: \(Self.refreshStatusDescription)", isError: true)
                self.saveLogs()
            }
        }
    }

    /// System permission for background refresh, for the Settings screen.
    var systemRefreshStatusLabel: String {
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return L10n.settingsBackgroundRefreshLowPower
        }
        switch UIApplication.shared.backgroundRefreshStatus {
        case .available: return L10n.settingsBackgroundRefreshAvailable
        case .denied: return L10n.settingsBackgroundRefreshDenied
        case .restricted: return L10n.settingsBackgroundRefreshRestricted
        @unknown default: return L10n.generalNA
        }
    }

    /// True when iOS will never launch the refresh task (switched off in Settings,
    /// or restricted). Low Power Mode pauses it too but turns itself off.
    var isSystemRefreshBlocked: Bool {
        UIApplication.shared.backgroundRefreshStatus != .available
    }

    /// Last background attempt for Settings, e.g. "Partial · 2 h ago".
    var lastRunSummary: String? {
        guard let raw = UserDefaults.standard.string(forKey: Self.lastRunOutcomeKey),
              let outcome = RunOutcome(rawValue: raw),
              let date = UserDefaults.standard.object(forKey: Self.lastRunDateKey) as? Date else {
            return nil
        }
        let label: String
        switch outcome {
        case .complete: label = L10n.settingsBackgroundRunComplete
        case .partial: label = L10n.settingsBackgroundRunPartial
        case .expired: label = L10n.settingsBackgroundRunExpired
        }
        return "\(label) · \(Self.relativeFormatter.localizedString(for: date, relativeTo: Date()))"
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    private static var refreshStatusDescription: String {
        switch UIApplication.shared.backgroundRefreshStatus {
        case .available: return ProcessInfo.processInfo.isLowPowerModeEnabled ? "available (Low Power Mode)" : "available"
        case .denied: return "denied"
        case .restricted: return "restricted"
        @unknown default: return "unknown"
        }
    }
    
    // MARK: - Task Handling
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        // The expiration handler and the normal path can both finish the task.
        // iOS must hear about it once, and before the window closes.
        let completion = TaskCompletion(task: task)
        
        let refreshTask = Task { @MainActor in
            self.log("Starting background refresh")
            let outcome = await MarketDataService.$isBackgroundBudget.withValue(true) {
                await self.performPriceRefresh()
            }
            self.recordRun(outcome)
            // Queue the next one from the updated `lastBackgroundRefresh`.
            self.scheduleAppRefresh()
            self.saveLogs()
            // Report success whenever the attempt ran. Per-ticker failures must not
            // be reported as task failure — iOS deprioritizes the app after false.
            completion.finish()
        }
        
        task.expirationHandler = {
            refreshTask.cancel()
            completion.finish()
            Task { @MainActor in
                self.log("Task expired by iOS", isError: true)
                self.recordRun(.expired)
                self.scheduleAppRefresh()
                self.saveLogs()
            }
        }
    }

    @MainActor
    private func recordRun(_ outcome: RunOutcome) {
        UserDefaults.standard.set(outcome.rawValue, forKey: Self.lastRunOutcomeKey)
        UserDefaults.standard.set(Date(), forKey: Self.lastRunDateKey)
    }
    
    // MARK: - Price Refresh Logic
    
    /// Exchange rates first (one request, needed for every EUR total), then prices
    /// in batches until the budget runs out. `lastBackgroundRefresh` is only written
    /// when every batch ran, so a partial run does not hold off the foreground refresh.
    @MainActor
    private func performPriceRefresh() async -> RunOutcome {
        let deadline = Date().addingTimeInterval(backgroundBudget)
        var successCount = 0
        var failureCount = 0

        if let rate = await MarketDataService.shared.fetchExchangeRate(from: "USD", to: "EUR") {
            await DatabaseService.shared.addExchangeRate(rate)
        } else {
            log("USD/EUR rate: failed to fetch", isError: true)
        }
        
        let instruments = await DatabaseService.shared.getAllInstruments()
        
        guard !instruments.isEmpty else {
            log("No instruments to refresh")
            UserDefaults.standard.set(Date(), forKey: "lastBackgroundRefresh")
            return .complete
        }
        
        log("Found \(instruments.count) instruments to refresh")

        // Fetch a few quotes at once instead of one-by-one with a pause, which
        // expired before the list finished.
        let batchSize = 4
        for batchStart in stride(from: 0, to: instruments.count, by: batchSize) {
            if Task.isCancelled || Date() >= deadline {
                log("Stopped early with \(successCount) updated, \(failureCount) failed", isError: true)
                return Task.isCancelled ? .expired : .partial
            }

            let batchEnd = min(batchStart + batchSize, instruments.count)
            let batch = Array(instruments[batchStart..<batchEnd])
            let results = await withTaskGroup(of: (Instrument, MarketDataResult).self) { group in
                for instrument in batch {
                    group.addTask {
                        let result = await MarketDataService.shared.fetchData(
                            isin: instrument.isin,
                            ticker: instrument.ticker
                        )
                        return (instrument, result)
                    }
                }
                var collected: [(Instrument, MarketDataResult)] = []
                for await pair in group {
                    collected.append(pair)
                }
                return collected
            }

            for (instrument, result) in results {
                let displayName = instrument.name ?? instrument.ticker ?? instrument.isin
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
            }
        }
        
        if Task.isCancelled {
            log("Cancelled after the last batch: \(successCount) success, \(failureCount) failed", isError: true)
            return .expired
        }
        UserDefaults.standard.set(Date(), forKey: "lastBackgroundRefresh")
        log("Refresh complete: \(successCount) success, \(failureCount) failed")
        return .complete
    }
}

/// Calls `setTaskCompleted` exactly once, from whichever path gets there first.
private final class TaskCompletion: @unchecked Sendable {
    private let task: BGTask
    private let lock = NSLock()
    private var finished = false

    init(task: BGTask) {
        self.task = task
    }

    func finish() {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return }
        finished = true
        task.setTaskCompleted(success: true)
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
            saveLogs()
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
