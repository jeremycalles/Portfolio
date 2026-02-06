import SwiftUI
import UniformTypeIdentifiers

// MARK: - iOS Settings View
struct iOSSettingsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var demoMode = DemoModeManager.shared
    @Binding var privacyMode: Bool
    @State private var showingImportPicker = false
    @State private var showingExportShare = false
    @State private var importMessage: String?
    @State private var showingAlert = false
    @State private var selectedStorage: StorageLocation = DatabaseService.shared.currentStorageLocation
    @State private var showingStorageChangeAlert = false
    @State private var showingBackgroundLogs = false
    @State private var showingAddAccountSheet = false
    @State private var showingAddQuadrantSheet = false
    
    var body: some View {
        List {
            Section {
                Picker(selection: $languageManager.currentLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                } label: {
                    Label(L10n.settingsLanguage, systemImage: "globe")
                }
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
                            viewModel.refreshAll()
                        } label: {
                            Label(L10n.settingsDemoModeRandomize, systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                    }
                }
            } header: {
                Text("Display")
            } footer: {
                Text(L10n.settingsDemoModeDescription)
            }
            
            Section {
                if DatabaseService.shared.iCloudAvailable {
                    Picker("Storage Location", selection: $selectedStorage) {
                        ForEach(StorageLocation.allCases, id: \.self) { location in
                            Text(location.displayName).tag(location)
                        }
                    }
                    .onChange(of: selectedStorage) { _, newValue in
                        if newValue != DatabaseService.shared.currentStorageLocation {
                            showingStorageChangeAlert = true
                        }
                    }
                    
                    if DatabaseService.shared.currentStorageLocation == .iCloud {
                        HStack {
                            Image(systemName: "checkmark.icloud.fill")
                                .foregroundColor(.blue)
                            Text("Syncing with iCloud")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "internaldrive")
                            .foregroundColor(.blue)
                        Text("Local Storage")
                    }
                    
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text("iCloud sync requires Apple Developer Program ($99/year)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Storage")
            } footer: {
                if DatabaseService.shared.iCloudAvailable {
                    Text("iCloud storage syncs your database across all your Apple devices.")
                } else {
                    Text("Use Import/Export to manually transfer your database between devices.")
                }
            }
            
            Section("Data Management") {
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
                }
                .disabled(viewModel.isLoading)
                
                Button {
                    Task {
                        await viewModel.backfillHistorical(period: "1y", interval: "1mo")
                    }
                } label: {
                    Label(L10n.actionBackfillHistorical1Year, systemImage: "clock.arrow.circlepath")
                }
                .disabled(viewModel.isLoading)
                
                Button {
                    Task {
                        await viewModel.backfillHistorical(period: "1mo", interval: "1d")
                    }
                } label: {
                    Label("Backfill 1 Month (Daily)", systemImage: "clock.arrow.circlepath")
                }
                .disabled(viewModel.isLoading)
            }
            
            Section {
                HStack {
                    Label(L10n.settingsBackgroundRefresh, systemImage: "arrow.clockwise.icloud")
                    Spacer()
                    Text("Every 3 hours")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onLongPressGesture {
                    showingBackgroundLogs = true
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
                Text("Background Updates")
            } footer: {
                Text("Prices are automatically updated in the background when the app is not in use. Long-press to view logs.")
            }
            
            Section("Database Import/Export") {
                Button {
                    showingImportPicker = true
                } label: {
                    Label("Import Database from File", systemImage: "square.and.arrow.down")
                }
                
                Button {
                    showingExportShare = true
                } label: {
                    Label("Export Database", systemImage: "square.and.arrow.up")
                }
            }
            
            Section("Database") {
                LabeledContent("Path") {
                    Text(DatabaseService.shared.getDatabasePath().components(separatedBy: "/").suffix(2).joined(separator: "/"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
                        Text("\(holdingsCount) holdings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            viewModel.deleteBankAccount(id: account.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                
                Button {
                    showingAddAccountSheet = true
                } label: {
                    Label("Add Account", systemImage: "plus.circle")
                }
            } header: {
                Text(L10n.navBankAccounts)
            } footer: {
                Text("Bank accounts are used to organize your holdings. Swipe left to delete.")
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
                            viewModel.deleteQuadrant(id: quadrant.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                
                Button {
                    showingAddQuadrantSheet = true
                } label: {
                    Label("Add Quadrant", systemImage: "plus.circle")
                }
            } header: {
                Text(L10n.navQuadrants)
            } footer: {
                Text("Quadrants categorize instruments for portfolio analysis. Assign via Instruments tab.")
            }
            
            Section("Statistics") {
                LabeledContent("Instruments", value: "\(viewModel.instruments.count)")
                LabeledContent(L10n.navHoldings, value: "\(viewModel.holdings.count)")
                LabeledContent(L10n.navQuadrants, value: "\(viewModel.quadrants.count)")
                LabeledContent(L10n.navBankAccounts, value: "\(viewModel.bankAccounts.count)")
            }
            
            Section("About") {
                LabeledContent("Version", value: "1.0.0")
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
                importMessage = "Import failed: \(error.localizedDescription)"
                showingAlert = true
            }
        }
        .sheet(isPresented: $showingExportShare) {
            if let dbURL = URL(fileURLWithPath: DatabaseService.shared.getDatabasePath()) as URL? {
                ShareSheet(items: [dbURL])
            }
        }
        .alert("Database Import", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(importMessage ?? "")
        }
        .alert("Change Storage Location", isPresented: $showingStorageChangeAlert) {
            Button("Move Data") {
                DatabaseService.shared.switchStorageLocation(to: selectedStorage, copyData: true)
                viewModel.refreshAll()
            }
            Button("Start Fresh") {
                DatabaseService.shared.switchStorageLocation(to: selectedStorage, copyData: false)
                viewModel.refreshAll()
            }
            Button("Cancel", role: .cancel) {
                selectedStorage = DatabaseService.shared.currentStorageLocation
            }
        } message: {
            Text("Would you like to move your existing data to \(selectedStorage.displayName), or start with a fresh database?")
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
    }
    
    private func importDatabase(from url: URL) {
        let destPath = DatabaseService.shared.getDatabasePath()
        let destURL = URL(fileURLWithPath: destPath)
        let destDir = destURL.deletingLastPathComponent()
        
        do {
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                importMessage = "Cannot access the selected file"
                showingAlert = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            // Create directory if needed
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            
            // Backup existing database
            if FileManager.default.fileExists(atPath: destPath) {
                let backupPath = destPath + ".backup"
                try? FileManager.default.removeItem(atPath: backupPath)
                try FileManager.default.moveItem(atPath: destPath, toPath: backupPath)
            }
            
            // Copy new database
            try FileManager.default.copyItem(at: url, to: destURL)
            
            importMessage = "Database imported successfully! Please restart the app to load the new data."
            showingAlert = true
            
            // Refresh data
            viewModel.refreshAll()
            
        } catch {
            importMessage = "Import failed: \(error.localizedDescription)"
            showingAlert = true
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
                    TextField("Quadrant Name", text: $quadrantName)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Quadrant Details")
                } footer: {
                    Text("Examples: 'Growth Stocks', 'Bonds', 'Real Estate', 'Gold'")
                }
            }
            .navigationTitle(L10n.quadrantsAddQuadrant)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let name = quadrantName.trimmingCharacters(in: .whitespaces)
                        viewModel.addQuadrant(name: name)
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
                    TextField("Bank Name", text: $bankName)
                        .textInputAutocapitalization(.words)
                    TextField("Account Name", text: $accountName)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Account Details")
                } footer: {
                    Text("Example: Bank = 'Degiro', Account = 'CTO' or 'PEA'")
                }
            }
            .navigationTitle(L10n.accountsAddAccount)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let bank = bankName.trimmingCharacters(in: .whitespaces)
                        let account = accountName.trimmingCharacters(in: .whitespaces)
                        viewModel.addBankAccount(bank: bank, account: account)
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
                            Text("No logs available")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Logs will appear here after the first background refresh occurs.")
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
            .navigationTitle("Background Refresh Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - iOS Change Label
// iOSChangeLabel consolidated into shared ChangeLabel
