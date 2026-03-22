import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - macOS Lock Gate View
struct MacOSLockGateView: View {
    @EnvironmentObject var viewModel: AppViewModel
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
            Task { await viewModel.refreshAll() }
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

    var body: some View {
        Form {
            // Mode Démo
            Section {
                PremiumSettingsRow(
                    title: L10n.settingsDemoModeEnable,
                    subtitle: L10n.settingsDemoModeDescription,
                    icon: "play.circle.fill",
                    iconColor: .blue
                ) {
                    Toggle("", isOn: $demoMode.isDemoModeEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                if demoMode.isDemoModeEnabled {
                    HStack {
                        Label(L10n.settingsDemoModeActive, systemImage: "info.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(6)
                        
                        Spacer()
                        
                        Button {
                            demoMode.regenerateSeed()
                            Task { await viewModel.refreshAll() }
                        } label: {
                            Label(L10n.settingsDemoModeRandomize, systemImage: "shuffle")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.leading, 42) // Align with text after icon
                }
            } header: {
                SettingsSectionHeader(title: L10n.settingsDemoMode, icon: "cpu", color: .blue)
            }

            // Gestion des données
            Section {
                PremiumSettingsRow(
                    title: L10n.settingsUpdatePrices,
                    subtitle: L10n.settingsUpdatePricesDescription,
                    icon: "arrow.clockwise.circle.fill",
                    iconColor: .green
                ) {
                    Button {
                        Task { await viewModel.updateAllPrices() }
                    } label: {
                        Text(L10n.actionUpdatePrices)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isLoading)
                }

                PremiumSettingsRow(
                    title: L10n.settingsBackfillData,
                    subtitle: L10n.settingsImportExportHint,
                    icon: "clock.arrow.circlepath",
                    iconColor: .green
                ) {
                    Menu {
                        Button(L10n.actionBackfill1Year) {
                            Task { await viewModel.backfillHistorical(period: "1y", interval: "1mo") }
                        }
                        Button(L10n.actionBackfill2Years) {
                            Task { await viewModel.backfillHistorical(period: "2y", interval: "1mo") }
                        }
                        Button(L10n.actionBackfill5Years) {
                            Task { await viewModel.backfillHistorical(period: "5y", interval: "1mo") }
                        }
                        Divider()
                        Button(L10n.actionBackfill1Month) {
                            Task { await viewModel.backfillHistorical(period: "1mo", interval: "1d") }
                        }
                    } label: {
                        Text(L10n.settingsBackfillData)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isLoading)
                }
            } header: {
                SettingsSectionHeader(title: L10n.settingsDataManagement, icon: "externaldrive.fill", color: .green)
            }

            // Protection Touch ID
            Section {
                PremiumSettingsRow(
                    title: L10n.settingsTouchIDProtectionEnable,
                    subtitle: L10n.settingsTouchIDProtectionDescription,
                    icon: "touchid",
                    iconColor: .orange
                ) {
                    Toggle("", isOn: $lockManager.isTouchIDProtectionEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            } header: {
                SettingsSectionHeader(title: L10n.settingsTouchIDProtection, icon: "lock.shield.fill", color: .orange)
            }

            // À propos
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) {
                        // App Icon Placeholder
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.appName)
                                .font(.headline)
                            Text(L10n.appTagline)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    HStack {
                        Text(L10n.settingsVersion)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(Bundle.appShortVersion)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    
                    HStack {
                        Text(L10n.generalBuild)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(Bundle.appBuildNumber)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                .padding(.vertical, 8)
            } header: {
                SettingsSectionHeader(title: L10n.settingsAbout, icon: "info.circle.fill", color: .purple)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }
}

// MARK: - Language Settings View
struct LanguageSettingsView: View {
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        Form {
            Section {
                PremiumSettingsRow(
                    title: L10n.settingsLanguage,
                    subtitle: L10n.settingsLanguageDescription,
                    icon: "globe",
                    iconColor: .blue
                ) {
                    Picker("", selection: $languageManager.currentLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 120)
                }
            } header: {
                SettingsSectionHeader(title: L10n.settingsLanguage, icon: "character.bubble.fill", color: .blue)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
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
            Section {
                PremiumSettingsRow(
                    title: L10n.settingsImportDatabase,
                    subtitle: L10n.settingsImportExportHint,
                    icon: "square.and.arrow.down.fill",
                    iconColor: .blue
                ) {
                    Button {
                        showingImportPicker = true
                    } label: {
                        Text(L10n.generalManage)
                    }
                    .buttonStyle(.bordered)
                }
                
                PremiumSettingsRow(
                    title: L10n.settingsExportDatabase,
                    icon: "square.and.arrow.up.fill",
                    iconColor: .blue
                ) {
                    Button {
                        exportDatabaseToFile()
                    } label: {
                        Text(L10n.generalData)
                    }
                    .buttonStyle(.bordered)
                }
                
                PremiumSettingsRow(
                    title: L10n.settingsStorageLogs,
                    subtitle: L10n.settingsStorageLogsDescription,
                    icon: "doc.text.magnifyingglass",
                    iconColor: .gray
                ) {
                    Button {
                        showingStorageLogs = true
                    } label: {
                        Text(L10n.generalOverview)
                    }
                    .buttonStyle(.bordered)
                }
            } header: {
                SettingsSectionHeader(title: L10n.settingsDatabaseImportExport, icon: "folder.fill", color: .blue)
            }
            
            Section {
                PremiumSettingsRow(
                    title: L10n.settingsDatabaseStoredLocally,
                    icon: "internaldrive.fill",
                    iconColor: .blue
                ) {
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
                            if isBackingUp {
                                ProgressView().controlSize(.small)
                            } else {
                                Text(L10n.settingsBackupToICloudNow)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isBackingUp)
                    }
                }
                
                PremiumSettingsRow(
                    title: "Database Path",
                    subtitle: DatabaseService.shared.getDatabasePath(),
                    icon: "link",
                    iconColor: .gray
                ) {
                    Button(L10n.settingsOpenInFinder) {
                        let path = DatabaseService.shared.getDatabasePath()
                        let url = URL(fileURLWithPath: path).deletingLastPathComponent()
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.bordered)
                }
            } header: {
                SettingsSectionHeader(title: L10n.settingsDatabase, icon: "cylinder.split.1x2.fill", color: .blue)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
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
        
        Task {
            guard url.startAccessingSecurityScopedResource() else {
                await MainActor.run {
                    importMessage = "Cannot access the selected file"
                    showingImportAlert = true
                }
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                await DatabaseService.shared.closeConnection()
                try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: destPath) {
                    let backupPath = destPath + ".backup"
                    try? FileManager.default.removeItem(atPath: backupPath)
                    try FileManager.default.moveItem(atPath: destPath, toPath: backupPath)
                }
                try FileManager.default.copyItem(at: url, to: destURL)
                await DatabaseService.shared.reconnectToDatabase()
                await MainActor.run {
                    importMessage = "Database imported successfully. Restart the app or switch views to load the new data."
                    showingImportAlert = true
                }
                NotificationCenter.default.post(name: .databaseDidImport, object: nil)
            } catch {
                await DatabaseService.shared.reconnectToDatabase()
                await MainActor.run {
                    importMessage = "Import failed: \(error.localizedDescription)"
                    showingImportAlert = true
                }
            }
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

// MARK: - Previews

#Preview("MacOSSystemSettingsView") {
    MacOSSystemSettingsView()
        .environmentObject(AppViewModel.preview)
        .environmentObject(LanguageManager.shared)
        .environmentObject(MacOSLockManager.shared)
}

#Preview("MacOSLockGateView") {
    MacOSLockGateView()
        .environmentObject(AppViewModel.preview)
        .environmentObject(MacOSLockManager.shared)
}
