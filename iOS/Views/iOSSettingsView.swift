import SwiftUI
import UniformTypeIdentifiers

struct iOSSettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var lockManager: IOSLockManager
    @StateObject private var demoMode = DemoModeManager.shared
    @Binding var privacyMode: Bool
    @State private var showingLanguage = false

    var body: some View {
        List {
            Section(L10n.designPrivacySecurity) {
                Toggle(isOn: $privacyMode) { Label(L10n.settingsPrivacyMode, systemImage: "eye.slash") }
                Toggle(isOn: $lockManager.isTouchIDProtectionEnabled) {
                    Label(L10n.designAppLock, systemImage: "lock.shield")
                }
                Text(L10n.designAppLockDescription).font(.caption).foregroundStyle(.secondary)
            }
            Section {
                NavigationLink { iOSBackupView() } label: {
                    Label(L10n.designBackupRestore, systemImage: "externaldrive")
                }
            } footer: { Text(L10n.designStoredLocally) }
            Section(L10n.designAppearanceLanguage) {
                Button { showingLanguage = true } label: {
                    LabeledContent(L10n.settingsLanguage, value: languageManager.currentLanguage.displayName)
                }.foregroundStyle(.primary)
                Toggle(isOn: $demoMode.isDemoModeEnabled) {
                    Label(L10n.settingsDemoModeEnable, systemImage: "theatermasks")
                }
                if demoMode.isDemoModeEnabled {
                    Text(L10n.settingsDemoModeDescription).font(.caption).foregroundStyle(.secondary)
                    Button(L10n.settingsDemoModeRandomize) {
                        demoMode.regenerateSeed()
                        Task { await viewModel.recomputeDashboardCache() }
                    }
                }
            }
            Section(L10n.settingsDataManagement) {
                NavigationLink(L10n.designManageAccounts) { iOSAccountsManagementView() }
                NavigationLink(L10n.designManageCategories) { iOSCategoriesManagementView() }
                NavigationLink(L10n.designManageInstruments) { iOSInstrumentsView() }
            }
            Section {
                NavigationLink(L10n.designAdvanced) { iOSAdvancedSettingsView() }
                LabeledContent(L10n.settingsVersion, value: Bundle.appShortVersion)
            }
        }
        .sheet(isPresented: $showingLanguage) {
            LanguagePickerSheet(selectedLanguage: $languageManager.currentLanguage)
        }
    }
}

struct iOSAdvancedSettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showingBackgroundLogs = false
    @State private var showingStorageLogs = false
    var body: some View {
        List {
            Section(L10n.settingsDataManagement) {
                Button(L10n.actionUpdateAllPrices) { Task { await viewModel.updateAllPrices() } }
                Button(L10n.actionBackfillHistorical1Year) {
                    Task { await viewModel.backfillHistorical(period: "1y", interval: "1mo") }
                }
                Button(L10n.actionBackfill1Month) {
                    Task { await viewModel.backfillHistorical(period: "1mo", interval: "1d") }
                }
            }.disabled(viewModel.isLoading)
            Section {
                LabeledContent(L10n.settingsBackgroundRefresh, value: L10n.settingsBackgroundRefreshInterval)
                LabeledContent(L10n.settingsBackgroundRefreshStatus, value: BackgroundTaskManager.shared.systemRefreshStatusLabel)
                if let last = BackgroundTaskManager.shared.timeSinceLastRefresh() {
                    LabeledContent(L10n.designLastChecked, value: last)
                }
                if BackgroundTaskManager.shared.isSystemRefreshBlocked {
                    Text(L10n.settingsBackgroundRefreshOffHint).foregroundStyle(.secondary)
                    Button(L10n.settingsOpenSystemSettings) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
            } header: { Text(L10n.settingsBackgroundUpdates) }
              footer: { Text(L10n.settingsBackgroundUpdatesLimits) }
            Section {
                Button(L10n.settingsBackgroundRefreshLogs) { showingBackgroundLogs = true }
                Button(L10n.settingsStorageLogs) { showingStorageLogs = true }
            }
        }
        .navigationTitle(L10n.designAdvanced)
        .sheet(isPresented: $showingBackgroundLogs) { BackgroundLogsView() }
        .sheet(isPresented: $showingStorageLogs) { StorageLogsView() }
    }
}

struct iOSBackupView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showingPicker = false
    @State private var pendingImport: URL?
    @State private var confirmRestore = false
    @State private var exportURL: URL?
    @State private var recoveryURL: URL?
    @State private var message: String?
    @State private var isBusy = false

    var body: some View {
        List {
            Section {
                if let exportURL {
                    ShareLink(item: exportURL) { Label(L10n.designExportBackup, systemImage: "square.and.arrow.up") }
                } else {
                    Button(L10n.designExportBackup) { Task { await prepareExport() } }
                }
                Button { showingPicker = true } label: {
                    Label(L10n.designRestoreBackup, systemImage: "square.and.arrow.down")
                }
                if let recoveryURL {
                    Button {
                        pendingImport = recoveryURL
                        confirmRestore = true
                    } label: { Label(L10n.designRestoreRecovery, systemImage: "clock.arrow.circlepath") }
                    ShareLink(item: recoveryURL) { Label(L10n.designExportRecovery, systemImage: "square.and.arrow.up") }
                }
            } footer: { Text(L10n.designBackupHint) }
            if DatabaseService.shared.iCloudBackupAvailable {
                Section {
                    Button(L10n.settingsBackupToICloudNow) {
                        isBusy = true
                        DatabaseService.shared.backupDatabaseToICloud { result in
                            isBusy = false
                            switch result {
                            case .success: message = L10n.settingsBackupCompleted
                            case .failure: message = L10n.errorSaveFailed
                            }
                        }
                    }
                }
            }
            if isBusy { ProgressView(L10n.designSaving) }
            if let message { Text(message).font(.callout).accessibilityAddTraits(.updatesFrequently) }
        }
        .disabled(isBusy || viewModel.isLoading || viewModel.demoMode.isDemoModeEnabled)
        .navigationTitle(L10n.designBackupRestore)
        .task { await prepareExport() }
        .fileImporter(isPresented: $showingPicker, allowedContentTypes: [.database, .data]) { result in
            switch result {
            case .success(let url): pendingImport = url; confirmRestore = true
            case .failure: message = L10n.settingsCannotAccessSelectedFile
            }
        }
        .confirmationDialog(L10n.designRestoreWarning, isPresented: $confirmRestore, titleVisibility: .visible) {
            Button(L10n.designRestoreConfirm, role: .destructive) {
                if let url = pendingImport { Task { await restore(url) } }
            }
            Button(L10n.generalCancel, role: .cancel) { pendingImport = nil }
        }
    }

    private func prepareExport() async {
        isBusy = true
        defer { isBusy = false }
        do {
            exportURL = try await viewModel.db.exportSnapshot()
            recoveryURL = viewModel.db.recoveryBackupURL
        } catch { message = L10n.errorSaveFailed }
    }

    private func restore(_ url: URL) async {
        isBusy = true
        defer { isBusy = false; pendingImport = nil }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            try await viewModel.db.restoreSnapshot(from: url)
            await viewModel.reloadAfterRestore()
            exportURL = try? await viewModel.db.exportSnapshot()
            recoveryURL = viewModel.db.recoveryBackupURL
            message = L10n.designRestoreSuccess
        } catch {
            recoveryURL = viewModel.db.recoveryBackupURL
            switch error {
            case DatabaseActor.BackupError.invalidFile: message = L10n.designInvalidBackup
            case DatabaseActor.BackupError.recoveryRequired: message = L10n.designRecoveryRequired
            default: message = L10n.designRestoreFailed
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
    @State private var isSaving = false
    
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
            .interactiveDismissDisabled(isSaving)
            .navigationTitle(L10n.quadrantsAddQuadrant)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.generalCancel) {
                        dismiss()
                    }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.generalAdd) {
                        let name = quadrantName.trimmingCharacters(in: .whitespaces)
                        isSaving = true
                        viewModel.dismissError()
                        Task {
                            await viewModel.addQuadrant(name: name)
                            isSaving = false
                            if viewModel.errorMessage == nil { dismiss() }
                        }
                    }
                    .disabled(!isValid || isSaving || viewModel.demoMode.isDemoModeEnabled)
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
    @State private var isSaving = false
    
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
            .interactiveDismissDisabled(isSaving)
            .navigationTitle(L10n.accountsAddAccount)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.generalCancel) {
                        dismiss()
                    }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.generalAdd) {
                        let bank = bankName.trimmingCharacters(in: .whitespaces)
                        let account = accountName.trimmingCharacters(in: .whitespaces)
                        isSaving = true
                        viewModel.dismissError()
                        Task {
                            await viewModel.addBankAccount(bank: bank, account: account)
                            isSaving = false
                            if viewModel.errorMessage == nil { dismiss() }
                        }
                    }
                    .disabled(!isValid || isSaving || viewModel.demoMode.isDemoModeEnabled)
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
