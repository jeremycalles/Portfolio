import SwiftUI
#if os(iOS)
import UIKit
#endif

@main
struct PortfolioApp: App {
    @StateObject private var viewModel = AppViewModel()
    @StateObject private var languageManager = LanguageManager.shared
    
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    #endif
    
    var body: some Scene {
        #if os(iOS)
        WindowGroup {
            iOSRootView()
                .environmentObject(viewModel)
                .environmentObject(languageManager)
                .id(languageManager.refreshID)  // Force view refresh on language change
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                BackgroundTaskManager.shared.appDidEnterBackground()
            case .active:
                BackgroundTaskManager.shared.appDidBecomeActive()
            default:
                break
            }
        }
        #else
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(languageManager)
                .id(languageManager.refreshID)  // Force view refresh on language change
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) { }
            
            CommandMenu(L10n.generalData) {
                Button(L10n.actionUpdateAllPrices) {
                    NotificationCenter.default.post(name: .updatePrices, object: nil)
                }
                .keyboardShortcut("u", modifiers: [.command])
                
                Divider()
                
                Button(L10n.actionBackfillHistorical1Year) {
                    NotificationCenter.default.post(name: .backfillHistorical, object: "1y")
                }
                
                Button(L10n.actionBackfillHistorical2Years) {
                    NotificationCenter.default.post(name: .backfillHistorical, object: "2y")
                }
                
                Button(L10n.actionBackfillHistorical5Years) {
                    NotificationCenter.default.post(name: .backfillHistorical, object: "5y")
                }
            }
        }
        
        Settings {
            MacOSSystemSettingsView()
                .environmentObject(languageManager)
                .id(languageManager.refreshID)  // Force view refresh on language change
        }
        #endif
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let updatePrices = Notification.Name("updatePrices")
    static let backfillHistorical = Notification.Name("backfillHistorical")
}

// MARK: - iOS App Delegate
#if os(iOS)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Register background tasks (required for handler to run)
        BackgroundTaskManager.shared.registerBackgroundTasks()
        // Schedule a refresh so one is queued even if user never sends app to background
        BackgroundTaskManager.shared.scheduleAppRefresh()
        return true
    }
}
#endif

// MARK: - macOS System Settings View (Preferences Window)
#if os(macOS)
struct MacOSSystemSettingsView: View {
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label(L10n.settingsGeneral, systemImage: "gear")
                }
            
            LanguageSettingsView()
                .tabItem {
                    Label(L10n.settingsLanguage, systemImage: "globe")
                }
            
            DatabaseSettingsView()
                .tabItem {
                    Label(L10n.settingsDatabase, systemImage: "cylinder")
                }
            
            BackgroundRefreshSettingsView()
                .tabItem {
                    Label(L10n.settingsBackground, systemImage: "arrow.clockwise")
                }
        }
        .frame(width: 550, height: 400)
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section(L10n.settingsAbout) {
                HStack {
                    Text(L10n.appName)
                        .font(.headline)
                    Spacer()
                    Text(L10n.appTagline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(L10n.settingsVersion)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

struct LanguageSettingsView: View {
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "globe")
                            .font(.title)
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.settingsLanguage)
                                .font(.headline)
                            Text(L10n.settingsLanguageDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Picker("", selection: $languageManager.currentLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            HStack {
                                Text(language.displayName)
                                if language == languageManager.currentLanguage {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .tag(language)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }
            }
        }
        .padding()
    }
}

struct DatabaseSettingsView: View {
    @State private var selectedStorage: StorageLocation = DatabaseService.shared.currentStorageLocation
    @State private var showingStorageChangeAlert = false
    
    var body: some View {
        Form {
            Section(L10n.settingsStorage) {
                if DatabaseService.shared.iCloudAvailable {
                    Picker("Storage", selection: $selectedStorage) {
                        ForEach(StorageLocation.allCases, id: \.self) { location in
                            Text(location.displayName).tag(location)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedStorage) { _, newValue in
                        if newValue != DatabaseService.shared.currentStorageLocation {
                            showingStorageChangeAlert = true
                        }
                    }
                    
                    HStack {
                        if DatabaseService.shared.currentStorageLocation == .iCloud {
                            Image(systemName: "checkmark.icloud.fill")
                                .foregroundColor(.blue)
                            Text(L10n.settingsSyncingWithICloud)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: "internaldrive")
                                .foregroundColor(.gray)
                            Text(L10n.settingsLocalStorageOnly)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "internaldrive")
                            .foregroundColor(.blue)
                        Text(L10n.settingsLocalStorage)
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text(L10n.settingsICloudRequirement)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Database Path") {
                HStack {
                    Text(DatabaseService.shared.getDatabasePath())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                
                Button(L10n.settingsOpenInFinder) {
                    let path = DatabaseService.shared.getDatabasePath()
                    let url = URL(fileURLWithPath: path).deletingLastPathComponent()
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .padding()
        .frame(width: 450, height: 250)
        .alert(L10n.settingsStorage, isPresented: $showingStorageChangeAlert) {
            Button(L10n.settingsMoveData) {
                DatabaseService.shared.switchStorageLocation(to: selectedStorage, copyData: true)
            }
            Button(L10n.settingsStartFresh) {
                DatabaseService.shared.switchStorageLocation(to: selectedStorage, copyData: false)
            }
            Button(L10n.generalCancel, role: .cancel) {
                selectedStorage = DatabaseService.shared.currentStorageLocation
            }
        } message: {
            Text(L10n.settingsMoveDataConfirmation(selectedStorage.displayName))
        }
    }
}

// MARK: - Launch Agent Manager
class LaunchAgentManager: ObservableObject {
    static let shared = LaunchAgentManager()
    
    private let agentLabel = "com.portfolio.app.pricerefresh"
    private let plistPath: String
    private let scriptPath: String
    private let logPath: String
    private let projectRootPath: String
    
    @Published var isInstalled: Bool = false
    @Published var isRunning: Bool = false
    @Published var lastRefreshLog: String = ""
    
    init() {
        let homePath = ProcessInfo.processInfo.environment["HOME"]
            ?? FileManager.default.homeDirectoryForCurrentUser.path
        projectRootPath = (homePath as NSString).appendingPathComponent("github/PortfolioMultiplatform")
        scriptPath = (projectRootPath as NSString).appendingPathComponent("scripts/refresh-prices.sh")
        logPath = (projectRootPath as NSString).appendingPathComponent("logs/refresh.log")
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        plistPath = homeDir.appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist").path
        checkStatus()
    }
    
    func checkStatus() {
        // Check if plist exists
        isInstalled = FileManager.default.fileExists(atPath: plistPath)
        
        // Check if agent is running
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
        
        // Read last log
        loadLastLog()
    }
    
    func loadLastLog() {
        if FileManager.default.fileExists(atPath: logPath) {
            do {
                let content = try String(contentsOfFile: logPath, encoding: .utf8)
                // Get last 50 lines
                let lines = content.components(separatedBy: .newlines)
                let lastLines = lines.suffix(50)
                lastRefreshLog = lastLines.joined(separator: "\n")
            } catch {
                lastRefreshLog = "Error reading log: \(error.localizedDescription)"
            }
        } else {
            lastRefreshLog = "No log file found yet. The background refresh will create logs when it runs."
        }
    }
    
    func install() {
        // The plist is already created, just load it
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["load", plistPath]
        
        do {
            try task.run()
            task.waitUntilExit()
            checkStatus()
        } catch {
            print("Failed to load launch agent: \(error)")
        }
    }
    
    func uninstall() {
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["unload", plistPath]
        
        do {
            try task.run()
            task.waitUntilExit()
            checkStatus()
        } catch {
            print("Failed to unload launch agent: \(error)")
        }
    }
    
    func runNow() {
        let task = Process()
        task.launchPath = scriptPath
        task.currentDirectoryURL = URL(fileURLWithPath: projectRootPath)
        
        do {
            try task.run()
            // Don't wait - let it run in background
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.loadLastLog()
            }
        } catch {
            print("Failed to run refresh script: \(error)")
        }
    }
    
    func openLogsInFinder() {
        let logsDir = URL(fileURLWithPath: (projectRootPath as NSString).appendingPathComponent("logs"))
        NSWorkspace.shared.open(logsDir)
    }
}

// MARK: - Background Refresh Settings View
struct BackgroundRefreshSettingsView: View {
    @StateObject private var manager = LaunchAgentManager.shared
    @State private var showingLogs = false
    
    var body: some View {
        Form {
            Section(L10n.settingsBackgroundRefresh) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.settingsAutomaticUpdates)
                            .font(.headline)
                        Text(L10n.settingsAutomaticUpdatesDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
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
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                            Text(L10n.settingsStatusNotInstalled)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
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
                        manager.runNow()
                    }
                    .disabled(!manager.isInstalled)
                    
                    Button(L10n.settingsRefreshStatus) {
                        manager.checkStatus()
                    }
                }
            }
            
            Section("Logs") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L10n.settingsRecentActivity)
                            .font(.headline)
                        Spacer()
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
        }
    }
}
#endif
