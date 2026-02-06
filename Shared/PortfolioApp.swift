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
                .onOpenURL { url in
                    guard url.scheme == "portfolio", url.host == "refresh" else { return }
                    Task {
                        await MacOSSchedulerManager.shared.performBackgroundRefresh()
                    }
                }
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

#endif
