import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - macOS Lock Gate View
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

// MARK: - General Settings View
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

// MARK: - Language Settings View
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

// MARK: - Database Settings View
struct DatabaseSettingsView: View {
    @State private var showingStorageLogs = false
    @State private var showingImportPicker = false
    @State private var showingImportAlert = false
    @State private var importMessage: String?
    @State private var showingBackupAlert = false
    @State private var backupAlertMessage: String?
    @State private var isBackingUp = false
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
                
                Button {
                    showingStorageLogs = true
                } label: {
                    Label(L10n.settingsStorageLogs, systemImage: "doc.text.magnifyingglass")
                }
            }
            
            Section(L10n.settingsDatabase) {
                HStack {
                    Image(systemName: "internaldrive")
                        .foregroundColor(.blue)
                    Text(L10n.settingsDatabaseStoredLocally)
                }
                if DatabaseService.shared.iCloudBackupAvailable {
                    Button {
                        isBackingUp = true
                        DatabaseService.shared.backupDatabaseToICloud { result in
                            isBackingUp = false
                            switch result {
                            case .success:
                                backupAlertMessage = "Backup completed."
                            case .failure(let error):
                                backupAlertMessage = error.localizedDescription
                            }
                            showingBackupAlert = true
                        }
                    } label: {
                        Label(L10n.settingsBackupToICloudNow, systemImage: "icloud.and.arrow.up")
                    }
                    .disabled(isBackingUp)
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
        .alert("Backup", isPresented: $showingBackupAlert) {
            Button(L10n.generalOk) { }
        } message: {
            Text(backupAlertMessage ?? "")
        }
        .sheet(isPresented: $showingStorageLogs) {
            StorageLogsView()
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
            
            DatabaseService.shared.closeConnection()
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destPath) {
                let backupPath = destPath + ".backup"
                try? FileManager.default.removeItem(atPath: backupPath)
                try FileManager.default.moveItem(atPath: destPath, toPath: backupPath)
            }
            try FileManager.default.copyItem(at: url, to: destURL)
            DatabaseService.shared.reconnectToDatabase()
            importMessage = "Database imported successfully. Restart the app or switch views to load the new data."
            showingImportAlert = true
            NotificationCenter.default.post(name: .databaseDidImport, object: nil)
        } catch {
            DatabaseService.shared.reconnectToDatabase()
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
