import SwiftUI
import UniformTypeIdentifiers

// MARK: - iOS Settings View
struct iOSSettingsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var lockManager: IOSLockManager
    @StateObject private var demoMode = DemoModeManager.shared
    @Binding var privacyMode: Bool
    @State private var showingImportPicker = false
    
    @State private var importMessage: String?
    @State private var showingAlert = false
    @State private var showingBackupAlert = false
    @State private var backupAlertMessage: String?
    @State private var isBackingUp = false
    @State private var showingBackgroundLogs = false
    @State private var showingStorageLogs = false
    @State private var showingAddAccountSheet = false
    @State private var showingAddQuadrantSheet = false
    @State private var showingLanguagePicker = false
    var body: some View {
        List {
            Section {
                Button {
                    showingLanguagePicker = true
                } label: {
                    HStack {
                        Label(L10n.settingsLanguage, systemImage: "globe")
                        Spacer()
                        Text(languageManager.currentLanguage.displayName)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } header: {
                Text(L10n.settingsLanguage)
            } footer: {
                Text(L10n.settingsLanguageDescription)
            }
            
            Section {
                Toggle(isOn: $privacyMode) {
                    Label(L10n.settingsPrivacyMode, systemImage: privacyMode ? "eye.slash" : "eye")
                }
                
                Toggle(isOn: $demoMode.isDemoModeEnabled) {
                    Label(L10n.settingsDemoModeEnable, systemImage: "theatermasks")
                }
                
                if demoMode.isDemoModeEnabled {
                    HStack {
                        Text(L10n.settingsDemoModeActive)
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Spacer()
                        
                        Button {
                            demoMode.regenerateSeed()
                            Task { await viewModel.refreshAll() }
                        } label: {
                            HStack {
                                Label(L10n.settingsDemoModeRandomize, systemImage: "arrow.clockwise")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text(L10n.settingsDisplay)
            } footer: {
                Text(L10n.settingsDemoModeDescription)
            }
            
            Section {
                Toggle(isOn: $lockManager.isTouchIDProtectionEnabled) {
                    Label(L10n.settingsTouchIDProtectionEnable, systemImage: "faceid")
                }
            } header: {
                Text(L10n.settingsTouchIDProtection)
            } footer: {
                Text(L10n.settingsTouchIDProtectionDescription)
            }
            
            Section {
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
                                backupAlertMessage = L10n.settingsBackupCompleted
                            case .failure(let error):
                                backupAlertMessage = error.localizedDescription
                            }
                            showingBackupAlert = true
                        }
                    } label: {
                        Label(L10n.settingsBackupToICloudNow, systemImage: "icloud.and.arrow.up")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isBackingUp)
                }
                Button {
                    showingImportPicker = true
                } label: {
                    Label(L10n.settingsImportDatabase, systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                ShareLink(item: URL(fileURLWithPath: DatabaseService.shared.getDatabasePath())) {
                    Label(L10n.settingsExportDatabase, systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                Button {
                    showingStorageLogs = true
                } label: {
                    Label(L10n.settingsStorageLogs, systemImage: "doc.text.magnifyingglass")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                LabeledContent(L10n.settingsPath) {
                    Text(DatabaseService.shared.getDatabasePath().components(separatedBy: "/").suffix(2).joined(separator: "/"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text(L10n.settingsDatabase)
            } footer: {
                Text(L10n.settingsImportExportPathHint)
            }
            
            Section(L10n.settingsDataManagement) {
                Button {
                    Task {
                        await viewModel.updateAllPrices()
                    }
                } label: {
                    HStack {
                        Label(L10n.actionUpdateAllPrices, systemImage: "arrow.clockwise")
                        if viewModel.isLoading {
                            Spacer()
                            ProgressView()
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)
                
                Button {
                    Task {
                        await viewModel.backfillHistorical(period: "1y", interval: "1mo")
                    }
                } label: {
                    Label(L10n.actionBackfillHistorical1Year, systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)
                
                Button {
                    Task {
                        await viewModel.backfillHistorical(period: "1mo", interval: "1d")
                    }
                } label: {
                    Label(L10n.actionBackfill1Month, systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)
            }
            
            Section {
                HStack {
                    Label(L10n.settingsBackgroundRefresh, systemImage: "arrow.clockwise.icloud")
                    Spacer()
                    Text(L10n.settingsBackgroundRefreshInterval)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
                .onLongPressGesture {
                    showingBackgroundLogs = true
                }
                
                HStack {
                    Text(L10n.settingsBackgroundRefreshStatus)
                    Spacer()
                    Text(BackgroundTaskManager.shared.systemRefreshStatusLabel)
                        .foregroundColor(.secondary)
                }
                if let lastRefresh = BackgroundTaskManager.shared.timeSinceLastRefresh() {
                    HStack {
                        Text(L10n.settingsLastRefresh)
                        Spacer()
                        Text(lastRefresh)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(L10n.settingsBackgroundUpdates)
            } footer: {
                Text(L10n.settingsBackgroundUpdatesDescription)
            }
            
            Section {
                ForEach(viewModel.bankAccounts) { account in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(account.bankName)
                                .font(.headline)
                            Text(account.accountName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        let holdingsCount = viewModel.holdings.filter { $0.accountId == account.id }.count
                        Text(L10n.accountsHoldingsCount(holdingsCount))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task { await viewModel.deleteBankAccount(id: account.id) }
                        } label: {
                            Label(L10n.generalDelete, systemImage: "trash")
                        }
                    }
                }
                
                Button {
                    showingAddAccountSheet = true
                } label: {
                    Label(L10n.accountsAddAccount, systemImage: "plus.circle")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } header: {
                Text(L10n.navBankAccounts)
            } footer: {
                Text(L10n.settingsAccountsHint)
            }
            
            Section {
                ForEach(viewModel.quadrants) { quadrant in
                    HStack {
                        Text(quadrant.name)
                        Spacer()
                        let instrumentCount = viewModel.instruments.filter { $0.quadrantId == quadrant.id }.count
                        Text("\(instrumentCount) instruments")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task { await viewModel.deleteQuadrant(id: quadrant.id) }
                        } label: {
                            Label(L10n.generalDelete, systemImage: "trash")
                        }
                    }
                }
                
                Button {
                    showingAddQuadrantSheet = true
                } label: {
                    Label(L10n.quadrantsAddQuadrant, systemImage: "plus.circle")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } header: {
                Text(L10n.navQuadrants)
            } footer: {
                Text(L10n.quadrantsCategorizeHint)
            }
            
            Section(L10n.settingsStatistics) {
                LabeledContent(L10n.instrumentsTitle, value: "\(viewModel.instruments.count)")
                LabeledContent(L10n.navHoldings, value: "\(viewModel.holdings.count)")
                LabeledContent(L10n.navQuadrants, value: "\(viewModel.quadrants.count)")
                LabeledContent(L10n.navBankAccounts, value: "\(viewModel.bankAccounts.count)")
            }
            
            Section(L10n.settingsAbout) {
                LabeledContent(L10n.settingsVersion, value: Bundle.appShortVersion)
                HStack {
                    Text(L10n.appName)
                    Spacer()
                    Text(L10n.appTagline)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
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
                importMessage = L10n.settingsImportFailed(error.localizedDescription)
                showingAlert = true
            }
        }
        
        .alert(L10n.settingsDatabaseImport, isPresented: $showingAlert) {
            Button(L10n.generalOk) { }
        } message: {
            Text(importMessage ?? "")
        }
        .alert(L10n.settingsBackup, isPresented: $showingBackupAlert) {
            Button(L10n.generalOk) { }
        } message: {
            Text(backupAlertMessage ?? "")
        }
        .sheet(isPresented: $showingStorageLogs) {
            StorageLogsView()
        }
        .sheet(isPresented: $showingBackgroundLogs) {
            BackgroundLogsView()
        }
        .sheet(isPresented: $showingAddAccountSheet) {
            AddBankAccountSheet()
        }
        .sheet(isPresented: $showingAddQuadrantSheet) {
            AddQuadrantSheet()
        }
        .sheet(isPresented: $showingLanguagePicker) {
            LanguagePickerSheet(
                selectedLanguage: Binding(
                    get: { languageManager.currentLanguage },
                    set: { languageManager.currentLanguage = $0 }
                )
            )
        }
    }
    
    private func importDatabase(from url: URL) {
        let destPath = DatabaseService.shared.getDatabasePath()
        let destURL = URL(fileURLWithPath: destPath)
        let destDir = destURL.deletingLastPathComponent()
        
        Task {
            guard url.startAccessingSecurityScopedResource() else {
                await MainActor.run {
                    importMessage = L10n.settingsCannotAccessSelectedFile
                    showingAlert = true
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
                    importMessage = L10n.settingsImportSucceededRestart
                    showingAlert = true
                }
                await viewModel.refreshAll()
            } catch {
                await DatabaseService.shared.reconnectToDatabase()
                await MainActor.run {
                    importMessage = L10n.settingsImportFailed(error.localizedDescription)
                    showingAlert = true
                }
            }
        }
    }
}

// MARK: - Language Picker Sheet
struct LanguagePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLanguage: AppLanguage
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        selectedLanguage = language
                        dismiss()
                    } label: {
                        HStack {
                            Text(language.displayName)
                            Spacer()
                            if language == selectedLanguage {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(L10n.settingsLanguage)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.generalDone) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Add Quadrant Sheet
struct AddQuadrantSheet: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var quadrantName = ""
    
    private var isValid: Bool {
        !quadrantName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.quadrantsName, text: $quadrantName)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text(L10n.quadrantsQuadrantDetails)
                } footer: {
                    Text(L10n.quadrantsDetailsHint)
                }
            }
            .navigationTitle(L10n.quadrantsAddQuadrant)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.generalCancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.generalAdd) {
                        let name = quadrantName.trimmingCharacters(in: .whitespaces)
                        Task { await viewModel.addQuadrant(name: name) }
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

// MARK: - Add Bank Account Sheet
struct AddBankAccountSheet: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var bankName = ""
    @State private var accountName = ""
    
    private var isValid: Bool {
        !bankName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !accountName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.accountsBankName, text: $bankName)
                        .textInputAutocapitalization(.words)
                    TextField(L10n.accountsAccountName, text: $accountName)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text(L10n.settingsAccountDetails)
                } footer: {
                    Text(L10n.settingsAccountDetailsHint)
                }
            }
            .navigationTitle(L10n.accountsAddAccount)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.generalCancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.generalAdd) {
                        let bank = bankName.trimmingCharacters(in: .whitespaces)
                        let account = accountName.trimmingCharacters(in: .whitespaces)
                        Task { await viewModel.addBankAccount(bank: bank, account: account) }
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

// MARK: - Background Logs View
struct BackgroundLogsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var taskManager = BackgroundTaskManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if taskManager.lastRefreshLogs.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text(L10n.settingsNoLogsAvailable)
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text(L10n.settingsLogsDescription)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        ForEach(taskManager.lastRefreshLogs) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: entry.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                                    .foregroundColor(entry.isError ? .red : .green)
                                    .font(.system(size: 14))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.message)
                                        .font(.system(size: 13, design: .monospaced))
                                    Text(entry.timestamp, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(L10n.settingsBackgroundRefreshLogs)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.generalDone) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("iOSSettingsView") {
    NavigationStack {
        iOSSettingsView(privacyMode: .constant(false))
            .environmentObject(AppViewModel.preview)
            .environmentObject(LanguageManager.shared)
            .environmentObject(IOSLockManager.shared)
    }
}
