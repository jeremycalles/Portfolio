import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
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
            IOSLockGateView()
                .environmentObject(viewModel)
                .environmentObject(languageManager)
                .environmentObject(IOSLockManager.shared)
                .id(languageManager.refreshID)  // Force view refresh on language change
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                if IOSLockManager.shared.isTouchIDProtectionEnabled {
                    IOSLockManager.shared.lock()
                }
                BackgroundTaskManager.shared.appDidEnterBackground()
            case .active:
                BackgroundTaskManager.shared.appDidBecomeActive()
            default:
                break
            }
        }
        #else
        WindowGroup {
            MacOSLockGateView()
                .environmentObject(viewModel)
                .environmentObject(languageManager)
                .environmentObject(MacOSLockManager.shared)
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
                .environmentObject(viewModel)
                .environmentObject(languageManager)
                .environmentObject(MacOSLockManager.shared)
                .id(languageManager.refreshID)  // Force view refresh on language change
        }
        #endif
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let updatePrices = Notification.Name("updatePrices")
    static let backfillHistorical = Notification.Name("backfillHistorical")
    static let databaseDidImport = Notification.Name("databaseDidImport")
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

// MARK: - macOS Lock Gate and System Settings
#if os(macOS)
struct MacOSLockGateView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var lockManager: MacOSLockManager
    
    var body: some View {
        Group {
            if !lockManager.isTouchIDProtectionEnabled || lockManager.isUnlocked {
                ContentView()
            } else {
                MacOSLockScreenView(lockManager: lockManager)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .databaseDidImport)) { _ in
            viewModel.refreshAll()
        }
    }
}

// MARK: - macOS System Settings View (Preferences Window)
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
        .frame(width: 560, height: 520)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var lockManager: MacOSLockManager
    @StateObject private var demoMode = DemoModeManager.shared

    private let sectionSpacing: CGFloat = 20
    private let footerTopPadding: CGFloat = 8

    var body: some View {
        Form {
                Section {
                    Toggle(L10n.settingsDemoModeEnable, isOn: $demoMode.isDemoModeEnabled)
                        .toggleStyle(.switch)
                    if demoMode.isDemoModeEnabled {
                        HStack {
                            Text(L10n.settingsDemoModeActive)
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(4)
                            Spacer()
                            Button {
                                demoMode.regenerateSeed()
                                viewModel.refreshAll()
                            } label: {
                                Label(L10n.settingsDemoModeRandomize, systemImage: "arrow.clockwise")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } header: {
                    sectionHeader(L10n.settingsDemoMode, isFirst: true)
                } footer: {
                    Text(L10n.settingsDemoModeDescription)
                        .padding(.top, footerTopPadding)
                }

                Section {
                    HStack(spacing: 14) {
                        Button {
                            Task {
                                await viewModel.updateAllPrices()
                            }
                        } label: {
                            Label(L10n.actionUpdatePrices, systemImage: "arrow.clockwise")
                        }
                        .disabled(viewModel.isLoading)

                        Menu {
                            Button(L10n.actionBackfill1Year) {
                                Task {
                                    await viewModel.backfillHistorical(period: "1y", interval: "1mo")
                                }
                            }
                            Button(L10n.actionBackfill2Years) {
                                Task {
                                    await viewModel.backfillHistorical(period: "2y", interval: "1mo")
                                }
                            }
                            Button(L10n.actionBackfill5Years) {
                                Task {
                                    await viewModel.backfillHistorical(period: "5y", interval: "1mo")
                                }
                            }
                            Divider()
                            Button(L10n.actionBackfill1Month) {
                                Task {
                                    await viewModel.backfillHistorical(period: "1mo", interval: "1d")
                                }
                            }
                        } label: {
                            Label(L10n.settingsBackfillData, systemImage: "clock.arrow.circlepath")
                        }
                        .disabled(viewModel.isLoading)
                    }
                    .padding(.vertical, 4)
                } header: {
                    sectionHeader(L10n.settingsDataManagement, isFirst: false)
                } footer: {
                    Text(L10n.settingsUpdatePricesDescription)
                        .padding(.top, footerTopPadding)
                }

                Section {
                    HStack {
                        Text(L10n.settingsTouchIDProtectionEnable)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 16)
                        Toggle("", isOn: $lockManager.isTouchIDProtectionEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                } header: {
                    sectionHeader(L10n.settingsTouchIDProtection, isFirst: false)
                } footer: {
                    Text(L10n.settingsTouchIDProtectionDescription)
                        .padding(.top, footerTopPadding)
                }

                Section {
                    HStack {
                        Text(L10n.appName)
                            .font(.headline)
                        Spacer()
                        Text(L10n.appTagline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)

                    HStack {
                        Text(L10n.settingsVersion)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)

                    HStack {
                        Text(L10n.generalBuild)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                    }
                    .padding(.vertical, 2)
                } header: {
                    sectionHeader(L10n.settingsAbout, isFirst: false)
                }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 28)
    }

    private func sectionHeader(_ title: String, isFirst: Bool) -> some View {
        Text(title)
            .padding(.top, isFirst ? 0 : sectionSpacing)
            .textCase(nil)
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
    @State private var showingImportPicker = false
    @State private var showingImportAlert = false
    @State private var importMessage: String?
    var body: some View {
        Form {
            Section(L10n.settingsDatabaseImportExport) {
                Button {
                    showingImportPicker = true
                } label: {
                    Label(L10n.settingsImportDatabase, systemImage: "square.and.arrow.down")
                }
                
                Button {
                    exportDatabaseToFile()
                } label: {
                    Label(L10n.settingsExportDatabase, systemImage: "square.and.arrow.up")
                }
            }
            
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
        .frame(minWidth: 450, minHeight: 320)
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.database, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importDatabase(from: url)
                }
            case .failure(let error):
                importMessage = "Import failed: \(error.localizedDescription)"
                showingImportAlert = true
            }
        }
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
        .alert("Database Import", isPresented: $showingImportAlert) {
            Button("OK") { }
        } message: {
            Text(importMessage ?? "")
        }
    }
    
    private func importDatabase(from url: URL) {
        let destPath = DatabaseService.shared.getDatabasePath()
        let destURL = URL(fileURLWithPath: destPath)
        let destDir = destURL.deletingLastPathComponent()
        
        do {
            guard url.startAccessingSecurityScopedResource() else {
                importMessage = "Cannot access the selected file"
                showingImportAlert = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destPath) {
                let backupPath = destPath + ".backup"
                try? FileManager.default.removeItem(atPath: backupPath)
                try FileManager.default.moveItem(atPath: destPath, toPath: backupPath)
            }
            try FileManager.default.copyItem(at: url, to: destURL)
            importMessage = "Database imported successfully. Restart the app or switch views to load the new data."
            showingImportAlert = true
            NotificationCenter.default.post(name: .databaseDidImport, object: nil)
        } catch {
            importMessage = "Import failed: \(error.localizedDescription)"
            showingImportAlert = true
        }
    }
    
    private func exportDatabaseToFile() {
        let path = DatabaseService.shared.getDatabasePath()
        guard FileManager.default.fileExists(atPath: path) else {
            importMessage = "Database file not found."
            showingImportAlert = true
            return
        }
        let sourceURL = URL(fileURLWithPath: path)
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.database, .data]
        savePanel.nameFieldStringValue = "stocks.db"
        savePanel.canCreateDirectories = true
        savePanel.begin { response in
            guard response == .OK, let destURL = savePanel.url else { return }
            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
            } catch {
                DispatchQueue.main.async {
                    importMessage = "Export failed: \(error.localizedDescription)"
                    showingImportAlert = true
                }
            }
        }
    }
}

#endif
