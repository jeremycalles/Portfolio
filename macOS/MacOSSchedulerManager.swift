#if os(macOS)
import SwiftUI
import AppKit
import ServiceManagement
import CoreFoundation

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
    
    private let logDir: URL
    private let logPath: URL
    
    @Published var isInstalled: Bool = false
    @Published var isRunning: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var lastRefreshLog: String = ""
    /// Shown when `SMAppService` registration fails or the login item needs user approval.
    @Published var launchAgentSetupError: String?
    
    @Published var selectedInterval: RefreshInterval {
        didSet {
            UserDefaults.standard.set(selectedInterval.rawValue, forKey: "refreshIntervalSeconds")
            refreshDefaults.set(selectedInterval.rawValue, forKey: PortfolioRefreshBridge.refreshIntervalSecondsKey)
            refreshDefaults.synchronize()
            postRefreshPrefsDarwinNotification()
            syncLoginItemHelperAfterPreferenceChange()
            if timerEnabled {
                startTimer()
            }
        }
    }
    
    @Published var timerEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(timerEnabled, forKey: "backgroundRefreshEnabled")
            refreshDefaults.set(timerEnabled, forKey: PortfolioRefreshBridge.backgroundRefreshEnabledKey)
            refreshDefaults.synchronize()
            postRefreshPrefsDarwinNotification()
            if timerEnabled {
                startTimer()
            } else {
                stopTimer()
            }
            syncLoginItemHelperAfterPreferenceChange()
        }
    }
    
    private var refreshTimer: Timer?
    
    private var refreshDefaults: UserDefaults {
        UserDefaults(suiteName: PortfolioRefreshBridge.appGroupIdentifier) ?? .standard
    }
    
    private var loginItemService: SMAppService {
        SMAppService.loginItem(identifier: PortfolioRefreshBridge.loginItemBundleIdentifier)
    }
    
    // MARK: - Init
    
    init() {
        if let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first {
            logDir = lib.appendingPathComponent("Logs/PortfolioApp", isDirectory: true)
        } else {
            logDir = FileManager.default.temporaryDirectory.appendingPathComponent("PortfolioAppLogs", isDirectory: true)
        }
        logPath = logDir.appendingPathComponent("refresh.log")
        
        let suite = UserDefaults(suiteName: PortfolioRefreshBridge.appGroupIdentifier)
        if let suite {
            if suite.object(forKey: PortfolioRefreshBridge.refreshIntervalSecondsKey) == nil {
                let v = UserDefaults.standard.integer(forKey: "refreshIntervalSeconds")
                if v != 0 {
                    suite.set(v, forKey: PortfolioRefreshBridge.refreshIntervalSecondsKey)
                }
            }
            if suite.object(forKey: PortfolioRefreshBridge.backgroundRefreshEnabledKey) == nil {
                suite.set(
                    UserDefaults.standard.bool(forKey: "backgroundRefreshEnabled"),
                    forKey: PortfolioRefreshBridge.backgroundRefreshEnabledKey
                )
            }
            suite.synchronize()
        }
        
        let suiteInterval = suite?.integer(forKey: PortfolioRefreshBridge.refreshIntervalSecondsKey) ?? 0
        let standardInterval = UserDefaults.standard.integer(forKey: "refreshIntervalSeconds")
        let resolvedInterval = suiteInterval != 0 ? suiteInterval : standardInterval
        selectedInterval = RefreshInterval(rawValue: resolvedInterval) ?? .threeHours
        
        let suiteTimer = suite?.object(forKey: PortfolioRefreshBridge.backgroundRefreshEnabledKey) as? Bool
        timerEnabled = suiteTimer ?? UserDefaults.standard.bool(forKey: "backgroundRefreshEnabled")
        
        checkStatus()
        loadLastLog()
        
        if timerEnabled {
            startTimer()
        }
    }
    
    private func migrateRefreshPreferencesFromStandardUserDefaults() {
        guard UserDefaults(suiteName: PortfolioRefreshBridge.appGroupIdentifier) != nil else { return }
        if refreshDefaults.object(forKey: PortfolioRefreshBridge.refreshIntervalSecondsKey) == nil {
            let v = UserDefaults.standard.integer(forKey: "refreshIntervalSeconds")
            if v != 0 {
                refreshDefaults.set(v, forKey: PortfolioRefreshBridge.refreshIntervalSecondsKey)
            }
        }
        if refreshDefaults.object(forKey: PortfolioRefreshBridge.backgroundRefreshEnabledKey) == nil {
            refreshDefaults.set(
                UserDefaults.standard.bool(forKey: "backgroundRefreshEnabled"),
                forKey: PortfolioRefreshBridge.backgroundRefreshEnabledKey
            )
        }
        refreshDefaults.synchronize()
    }
    
    private func postRefreshPrefsDarwinNotification() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(PortfolioRefreshBridge.refreshPrefsDarwinNotification),
            nil,
            nil,
            true
        )
    }
    
    /// If the login item is enabled but no helper process is running, launch it (e.g. after toggling preferences).
    private func syncLoginItemHelperAfterPreferenceChange() {
        guard isInstalled, timerEnabled else { return }
        let bid = PortfolioRefreshBridge.loginItemBundleIdentifier
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bid)
        if running.isEmpty {
            Task { await launchEmbeddedLoginItem() }
        }
    }
    
    // MARK: - Status Check
    
    func checkStatus() {
        switch loginItemService.status {
        case .enabled:
            isInstalled = true
            isRunning = true
        case .requiresApproval:
            isInstalled = true
            isRunning = false
        default:
            isInstalled = false
            isRunning = false
        }
    }
    
    // MARK: - Install / Uninstall (SMAppService + embedded login item)
    
    func install() async {
        launchAgentSetupError = nil
        migrateRefreshPreferencesFromStandardUserDefaults()
        refreshDefaults.set(selectedInterval.rawValue, forKey: PortfolioRefreshBridge.refreshIntervalSecondsKey)
        refreshDefaults.set(true, forKey: PortfolioRefreshBridge.backgroundRefreshEnabledKey)
        refreshDefaults.synchronize()
        postRefreshPrefsDarwinNotification()
        
        do {
            try loginItemService.register()
        } catch {
            let message = error.localizedDescription
            launchAgentSetupError = L10n.settingsLoginItemRegistrationFailed(message)
            appendLog("Login item registration failed: \(message)", isError: true)
            checkStatus()
            return
        }
        
        checkStatus()
        appendLog("Login item registered (interval: \(selectedInterval.displayName))")
        
        if loginItemService.status == .requiresApproval {
            launchAgentSetupError = L10n.settingsLoginItemRequiresApproval
        }
        
        if !timerEnabled {
            timerEnabled = true
        }
        
        await launchEmbeddedLoginItem()
    }
    
    func uninstall() {
        launchAgentSetupError = nil
        terminateLoginItemHelper()
        do {
            try loginItemService.unregister()
        } catch {
            let message = error.localizedDescription
            launchAgentSetupError = L10n.settingsLoginItemRegistrationFailed(message)
            appendLog("Login item unregister failed: \(message)", isError: true)
        }
        refreshDefaults.set(false, forKey: PortfolioRefreshBridge.backgroundRefreshEnabledKey)
        refreshDefaults.synchronize()
        postRefreshPrefsDarwinNotification()
        if timerEnabled {
            timerEnabled = false
        }
        checkStatus()
        appendLog("Login item unregistered")
    }
    
    func openLoginItemsSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func terminateLoginItemHelper() {
        let bid = PortfolioRefreshBridge.loginItemBundleIdentifier
        NSRunningApplication.runningApplications(withBundleIdentifier: bid).forEach { $0.terminate() }
    }
    
    private func launchEmbeddedLoginItem() async {
        let url = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LoginItems", isDirectory: true)
            .appendingPathComponent("PortfolioRefreshLoginItem.app", isDirectory: true)
        guard FileManager.default.fileExists(atPath: url.path) else {
            appendLog("Login item helper missing from app bundle (expected at \(url.path))", isError: true)
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        } catch {
            appendLog("Could not start login item helper: \(error.localizedDescription)", isError: true)
        }
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
        
        let instruments = await DatabaseService.shared.getAllInstruments()
        
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
                await DatabaseService.shared.addPrice(newPrice)
                
                // Update instrument info if available (but NOT currency)
                if result.name != nil || result.ticker != nil {
                    var updatedInstrument = instrument
                    if let name = result.name { updatedInstrument.name = name }
                    if let ticker = result.ticker { updatedInstrument.ticker = ticker }
                    await DatabaseService.shared.addOrUpdateInstrument(updatedInstrument)
                }
                
                appendLog("\(displayName): \(String(format: "%.2f", price)) \(result.currency ?? "")")
                successCount += 1
            } else {
                let reason = result.failureReason ?? "unknown"
                appendLog("\(displayName): \(reason)", isError: true)
                failureCount += 1
            }
            
            // Small delay to avoid rate limiting
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        // Update exchange rates
        appendLog("Updating exchange rates...")
        if let rate = await MarketDataService.shared.fetchExchangeRate(from: "USD", to: "EUR") {
            await DatabaseService.shared.addExchangeRate(rate)
            appendLog("USD/EUR rate updated")
        }
        
        // Fetch benchmarks
        appendLog("Fetching benchmark data...")
        async let sp500Prices = MarketDataService.shared.fetchSP500History(period: "2y", interval: "1d")
        async let goldPrices = MarketDataService.shared.fetchGoldHistory(period: "2y", interval: "1d")
        async let msciPrices = MarketDataService.shared.fetchMSCIWorldHistory(period: "2y", interval: "1d")
        
        let (sp500Result, goldResult, msciResult) = await (sp500Prices, goldPrices, msciPrices)
        
        for price in sp500Result { await DatabaseService.shared.addPrice(price) }
        for price in goldResult { await DatabaseService.shared.addPrice(price) }
        for price in msciResult { await DatabaseService.shared.addPrice(price) }
        
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
            Section {
                // Status Header
                PremiumSettingsRow(
                    title: L10n.settingsAutomaticUpdates,
                    subtitle: L10n.settingsAutomaticUpdatesDescription,
                    icon: "arrow.clockwise.circle.fill",
                    iconColor: .blue
                ) {
                    statusBadge
                }
                
                // Interval Picker
                PremiumSettingsRow(
                    title: L10n.settingsBackgroundRefreshInterval,
                    icon: "timer",
                    iconColor: .gray
                ) {
                    Picker("", selection: $manager.selectedInterval) {
                        ForEach(RefreshInterval.allCases) { interval in
                            Text(interval.displayName).tag(interval)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 120)
                }
                
                // Last Refresh info
                if let lastRefresh = manager.timeSinceLastRefresh() {
                    PremiumSettingsRow(
                        title: L10n.settingsLastRefresh,
                        subtitle: lastRefresh,
                        icon: "clock.fill",
                        iconColor: .gray
                    ) {
                        EmptyView()
                    }
                }
                
                // Actions
                VStack(alignment: .leading, spacing: 12) {
                    if let setupError = manager.launchAgentSetupError {
                        Label(setupError, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                    }
                    
                    if manager.isInstalled && !manager.isRunning {
                        Button(L10n.settingsOpenLoginItemsSettings) {
                            manager.openLoginItemsSystemSettings()
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                    
                    HStack(spacing: 12) {
                        if manager.isInstalled {
                            Button(L10n.settingsDisable) {
                                manager.uninstall()
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button(L10n.settingsEnable) {
                                Task { await manager.install() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        Button(L10n.settingsRunNow) {
                            Task { await manager.performBackgroundRefresh() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(manager.isRefreshing)
                        
                        if manager.isRefreshing {
                            ProgressView().controlSize(.small)
                        }
                        
                        Spacer()
                        
                        Button(L10n.settingsRefreshStatus) {
                            manager.checkStatus()
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                }
                .padding(.vertical, 4)
                .padding(.leading, 42)
            } header: {
                SettingsSectionHeader(title: L10n.settingsBackgroundRefresh, icon: "arrow.clockwise", color: .blue)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(L10n.settingsRecentActivity, systemImage: "list.bullet.rectangle.fill")
                            .font(.headline)
                        
                        Spacer()
                        
                        HStack(spacing: 16) {
                            Button("Clear") {
                                manager.clearLogs()
                            }
                            .buttonStyle(.link)
                            
                            Button(L10n.settingsOpenLogsFolder) {
                                manager.openLogsInFinder()
                            }
                            .buttonStyle(.link)
                        }
                        .font(.caption)
                    }
                    
                    ScrollView {
                        Text(manager.lastRefreshLog)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(height: 140)
                    .padding(10)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
                }
                .padding(.vertical, 8)
            } header: {
                SettingsSectionHeader(title: "Logs", icon: "doc.text.fill", color: .gray)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
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
            .font(.caption.bold())
        } else if manager.isInstalled {
            HStack(spacing: 4) {
                Image(systemName: "pause.circle.fill")
                    .foregroundColor(.orange)
                Text(L10n.settingsStatusInstalledNotRunning)
                    .foregroundColor(.orange)
            }
            .font(.caption.bold())
        } else if manager.timerEnabled {
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .foregroundColor(.blue)
                Text("In-app timer active")
                    .foregroundColor(.blue)
            }
            .font(.caption.bold())
        } else {
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                Text(L10n.settingsStatusNotInstalled)
                    .foregroundColor(.secondary)
            }
            .font(.caption.bold())
        }
    }
}
#endif
