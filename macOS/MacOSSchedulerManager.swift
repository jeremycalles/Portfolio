#if os(macOS)
import SwiftUI
import AppKit

// MARK: - Refresh Interval
enum RefreshInterval: Int, CaseIterable, Identifiable {
    case oneHour = 3600
    case threeHours = 10800
    case sixHours = 21600
    case twelveHours = 43200
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .oneHour: return "1 hour"
        case .threeHours: return "3 hours"
        case .sixHours: return "6 hours"
        case .twelveHours: return "12 hours"
        }
    }
}

// MARK: - macOS Scheduler Manager
@MainActor
class MacOSSchedulerManager: ObservableObject {
    static let shared = MacOSSchedulerManager()
    
    private let agentLabel = "com.portfolio.app.pricerefresh"
    private let plistPath: String
    private let logDir: URL
    private let logPath: URL
    
    @Published var isInstalled: Bool = false
    @Published var isRunning: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var lastRefreshLog: String = ""
    
    @Published var selectedInterval: RefreshInterval {
        didSet {
            UserDefaults.standard.set(selectedInterval.rawValue, forKey: "refreshIntervalSeconds")
            // If installed, reinstall with new interval
            if isInstalled {
                reinstall()
            }
            // Restart in-app timer with new interval
            if timerEnabled {
                startTimer()
            }
        }
    }
    
    @Published var timerEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(timerEnabled, forKey: "backgroundRefreshEnabled")
            if timerEnabled {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }
    
    private var refreshTimer: Timer?
    
    // MARK: - Init
    
    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        plistPath = homeDir.appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist").path
        logDir = homeDir.appendingPathComponent("Library/Logs/PortfolioApp")
        logPath = logDir.appendingPathComponent("refresh.log")
        
        // Load persisted interval
        let savedInterval = UserDefaults.standard.integer(forKey: "refreshIntervalSeconds")
        selectedInterval = RefreshInterval(rawValue: savedInterval) ?? .threeHours
        
        // Load persisted timer state
        timerEnabled = UserDefaults.standard.bool(forKey: "backgroundRefreshEnabled")
        
        checkStatus()
        loadLastLog()
        
        // Auto-start timer if enabled
        if timerEnabled {
            startTimer()
        }
    }
    
    // MARK: - Status Check
    
    func checkStatus() {
        isInstalled = FileManager.default.fileExists(atPath: plistPath)
        
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["list", agentLabel]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            isRunning = task.terminationStatus == 0
        } catch {
            isRunning = false
        }
    }
    
    // MARK: - Plist Generation
    
    private func generatePlist() -> [String: Any] {
        return [
            "Label": agentLabel,
            "ProgramArguments": ["/usr/bin/open", "-g", "portfolio://refresh"],
            "StartInterval": selectedInterval.rawValue,
            "StandardOutPath": logDir.appendingPathComponent("launchagent.stdout.log").path,
            "StandardErrorPath": logDir.appendingPathComponent("launchagent.stderr.log").path,
            "RunAtLoad": true,
        ]
    }
    
    private func writePlist() -> Bool {
        // Ensure LaunchAgents directory exists
        let launchAgentsDir = (plistPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: launchAgentsDir, withIntermediateDirectories: true)
        
        // Ensure log directory exists
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        
        let plistData = generatePlist()
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: plistData, format: .xml, options: 0)
            try data.write(to: URL(fileURLWithPath: plistPath))
            return true
        } catch {
            appendLog("Failed to write plist: \(error.localizedDescription)", isError: true)
            return false
        }
    }
    
    // MARK: - Install / Uninstall
    
    func install() {
        guard writePlist() else { return }
        
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["load", plistPath]
        
        do {
            try task.run()
            task.waitUntilExit()
            appendLog("Launch Agent installed (interval: \(selectedInterval.displayName))")
        } catch {
            appendLog("Failed to load launch agent: \(error.localizedDescription)", isError: true)
        }
        
        checkStatus()
        
        // Also enable the in-app timer
        if !timerEnabled {
            timerEnabled = true
        }
    }
    
    func uninstall() {
        // Unload if running
        if isInstalled {
            let task = Process()
            task.launchPath = "/bin/launchctl"
            task.arguments = ["unload", plistPath]
            
            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                appendLog("Failed to unload launch agent: \(error.localizedDescription)", isError: true)
            }
            
            // Remove plist file
            try? FileManager.default.removeItem(atPath: plistPath)
            appendLog("Launch Agent uninstalled")
        }
        
        checkStatus()
        
        // Also stop the in-app timer
        if timerEnabled {
            timerEnabled = false
        }
    }
    
    func reinstall() {
        // Unload existing
        if isInstalled {
            let unloadTask = Process()
            unloadTask.launchPath = "/bin/launchctl"
            unloadTask.arguments = ["unload", plistPath]
            do {
                try unloadTask.run()
                unloadTask.waitUntilExit()
            } catch {
                // Ignore — may not be loaded
            }
        }
        
        // Write new plist with updated interval
        guard writePlist() else { return }
        
        // Load
        let loadTask = Process()
        loadTask.launchPath = "/bin/launchctl"
        loadTask.arguments = ["load", plistPath]
        do {
            try loadTask.run()
            loadTask.waitUntilExit()
            appendLog("Launch Agent reinstalled (interval: \(selectedInterval.displayName))")
        } catch {
            appendLog("Failed to reload launch agent: \(error.localizedDescription)", isError: true)
        }
        
        checkStatus()
    }
    
    // MARK: - In-App Timer
    
    func startTimer() {
        stopTimer()
        let interval = TimeInterval(selectedInterval.rawValue)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performBackgroundRefresh()
            }
        }
        // Keep timer alive during modal run loops
        if let timer = refreshTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Shared Refresh Logic
    
    func performBackgroundRefresh() async {
        guard !isRefreshing else {
            appendLog("Refresh already in progress, skipping")
            return
        }
        
        isRefreshing = true
        appendLog("Starting background refresh")
        
        var successCount = 0
        var failureCount = 0
        
        let instruments = DatabaseService.shared.getAllInstruments()
        
        guard !instruments.isEmpty else {
            appendLog("No instruments to refresh")
            isRefreshing = false
            return
        }
        
        appendLog("Found \(instruments.count) instruments to refresh")
        
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
                
                // Update instrument info if available (but NOT currency)
                if result.name != nil || result.ticker != nil {
                    var updatedInstrument = instrument
                    if let name = result.name { updatedInstrument.name = name }
                    if let ticker = result.ticker { updatedInstrument.ticker = ticker }
                    DatabaseService.shared.addOrUpdateInstrument(updatedInstrument)
                }
                
                appendLog("\(displayName): \(String(format: "%.2f", price)) \(result.currency ?? "")")
                successCount += 1
            } else {
                appendLog("\(displayName): Failed to fetch price", isError: true)
                failureCount += 1
            }
            
            // Small delay to avoid rate limiting
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        // Update exchange rates
        appendLog("Updating exchange rates...")
        if let rate = await MarketDataService.shared.fetchExchangeRate(from: "USD", to: "EUR") {
            DatabaseService.shared.addExchangeRate(rate)
            appendLog("USD/EUR rate updated")
        }
        
        // Fetch benchmarks
        appendLog("Fetching benchmark data...")
        async let sp500Prices = MarketDataService.shared.fetchSP500History(period: "2y", interval: "1d")
        async let goldPrices = MarketDataService.shared.fetchGoldHistory(period: "2y", interval: "1d")
        async let msciPrices = MarketDataService.shared.fetchMSCIWorldHistory(period: "2y", interval: "1d")
        
        let (sp500Result, goldResult, msciResult) = await (sp500Prices, goldPrices, msciPrices)
        
        for price in sp500Result { DatabaseService.shared.addPrice(price) }
        for price in goldResult { DatabaseService.shared.addPrice(price) }
        for price in msciResult { DatabaseService.shared.addPrice(price) }
        
        appendLog("Benchmarks updated (S&P500: \(sp500Result.count), Gold: \(goldResult.count), MSCI: \(msciResult.count))")
        
        // Save last refresh time
        UserDefaults.standard.set(Date(), forKey: "lastBackgroundRefresh")
        
        appendLog("Refresh complete: \(successCount) success, \(failureCount) failed")
        isRefreshing = false
        
        // Restart timer to avoid double-refresh soon after manual trigger
        if timerEnabled {
            startTimer()
        }
    }
    
    // MARK: - Logging
    
    private func appendLog(_ message: String, isError: Bool = false) {
        let prefix = isError ? "ERROR" : "OK"
        let timestamp = AppDateFormatter.yearMonthDayTime.string(from: Date())
        let line = "[\(timestamp)] [\(prefix)] \(message)"
        
        // Append to file
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        
        if FileManager.default.fileExists(atPath: logPath.path) {
            if let handle = FileHandle(forWritingAtPath: logPath.path) {
                handle.seekToEndOfFile()
                handle.write((line + "\n").data(using: .utf8) ?? Data())
                handle.closeFile()
            }
        } else {
            try? (line + "\n").write(to: logPath, atomically: true, encoding: .utf8)
        }
        
        // Update in-memory log display
        loadLastLog()
        
        print("[MacOSScheduler] \(message)")
    }
    
    func loadLastLog() {
        guard FileManager.default.fileExists(atPath: logPath.path) else {
            lastRefreshLog = L10n.settingsLogsDescription
            return
        }
        
        do {
            let content = try String(contentsOf: logPath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            let lastLines = lines.suffix(50)
            lastRefreshLog = lastLines.joined(separator: "\n")
        } catch {
            lastRefreshLog = "Error reading log: \(error.localizedDescription)"
        }
    }
    
    func clearLogs() {
        try? FileManager.default.removeItem(at: logPath)
        lastRefreshLog = L10n.settingsLogsDescription
    }
    
    func openLogsInFinder() {
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(logDir)
    }
    
    // MARK: - Launch Prompt
    
    /// Whether we should show the "enable automatic refresh?" prompt at launch.
    /// True when auto-refresh is not set up AND the user hasn't dismissed the prompt permanently.
    var shouldPromptForAutoRefresh: Bool {
        !isInstalled && !timerEnabled && !UserDefaults.standard.bool(forKey: "dismissedAutoRefreshPrompt")
    }
    
    func dismissPromptPermanently() {
        UserDefaults.standard.set(true, forKey: "dismissedAutoRefreshPrompt")
    }
    
    // MARK: - Last Refresh Time
    
    func timeSinceLastRefresh() -> String? {
        guard let lastRefresh = UserDefaults.standard.object(forKey: "lastBackgroundRefresh") as? Date else {
            return nil
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastRefresh, relativeTo: Date())
    }
}

// MARK: - Background Refresh Settings View
struct BackgroundRefreshSettingsView: View {
    @StateObject private var manager = MacOSSchedulerManager.shared
    
    var body: some View {
        Form {
            Section(L10n.settingsBackgroundRefresh) {
                // Status header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.settingsAutomaticUpdates)
                            .font(.headline)
                        Text(L10n.settingsAutomaticUpdatesDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    statusBadge
                }
                
                // Interval picker
                Picker("Refresh interval", selection: $manager.selectedInterval) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .pickerStyle(.segmented)
                
                // Last refresh
                if let lastRefresh = manager.timeSinceLastRefresh() {
                    HStack {
                        Text(L10n.settingsLastRefresh)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(lastRefresh)
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
                
                // Action buttons
                HStack(spacing: 12) {
                    if manager.isInstalled {
                        Button(L10n.settingsDisable) {
                            manager.uninstall()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button(L10n.settingsEnable) {
                            manager.install()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Button(L10n.settingsRunNow) {
                        Task {
                            await manager.performBackgroundRefresh()
                        }
                    }
                    .disabled(manager.isRefreshing)
                    
                    if manager.isRefreshing {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    
                    Spacer()
                    
                    Button(L10n.settingsRefreshStatus) {
                        manager.checkStatus()
                    }
                    .buttonStyle(.link)
                }
            }
            
            Section("Logs") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L10n.settingsRecentActivity)
                            .font(.headline)
                        Spacer()
                        
                        Button("Clear") {
                            manager.clearLogs()
                        }
                        .buttonStyle(.link)
                        
                        Button(L10n.settingsOpenLogsFolder) {
                            manager.openLogsInFinder()
                        }
                        .buttonStyle(.link)
                    }
                    
                    ScrollView {
                        Text(manager.lastRefreshLog)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(height: 120)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)
                }
            }
        }
        .padding()
        .onAppear {
            manager.checkStatus()
            manager.loadLastLog()
        }
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        if manager.isInstalled && manager.isRunning {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(L10n.settingsStatusActive)
                    .foregroundColor(.green)
            }
        } else if manager.isInstalled {
            HStack(spacing: 4) {
                Image(systemName: "pause.circle.fill")
                    .foregroundColor(.orange)
                Text(L10n.settingsStatusInstalledNotRunning)
                    .foregroundColor(.orange)
            }
        } else if manager.timerEnabled {
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .foregroundColor(.blue)
                Text("In-app timer active")
                    .foregroundColor(.blue)
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                Text(L10n.settingsStatusNotInstalled)
                    .foregroundColor(.secondary)
            }
        }
    }
}
#endif
