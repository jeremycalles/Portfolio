import SwiftUI

#if os(macOS)
// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @StateObject private var languageManager = LanguageManager.shared
    @State private var selectedTab = 0
    @State private var showAutoRefreshPrompt = false
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section(L10n.generalOverview) {
                    Label(L10n.navDashboard, systemImage: "chart.pie.fill")
                        .tag(0)
                    Label(L10n.navQuadrantReport, systemImage: "square.grid.2x2.fill")
                        .tag(1)
                    Label(L10n.navAllHoldings, systemImage: "list.bullet.rectangle.fill")
                        .tag(7)
                }
                
                Section(L10n.generalManage) {
                    Label(L10n.navInstruments, systemImage: "doc.text.fill")
                        .tag(2)
                    Label(L10n.navQuadrants, systemImage: "folder.fill")
                        .tag(3)
                    Label(L10n.navBankAccounts, systemImage: "building.columns.fill")
                        .tag(4)
                    Label(L10n.navHoldings, systemImage: "creditcard.fill")
                        .tag(5)
                }
                
                Section(L10n.generalData) {
                    Label(L10n.navPriceHistory, systemImage: "chart.line.uptrend.xyaxis")
                        .tag(6)
                    Label(L10n.navPriceGraph, systemImage: "chart.xyaxis.line")
                        .tag(8)
                }
                
                Section {
                    Label(L10n.navSettings, systemImage: "gear")
                        .tag(9)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(L10n.appName)
        } detail: {
            ZStack {
                switch selectedTab {
                case 0:
                    DashboardView()
                case 1:
                    QuadrantReportView()
                case 2:
                    InstrumentsView()
                case 3:
                    QuadrantsView()
                case 4:
                    BankAccountsView()
                case 5:
                    HoldingsView()
                case 6:
                    PriceHistoryView()
                case 7:
                    AllHoldingsView()
                case 8:
                    PriceGraphView()
                case 9:
                    SettingsView()
                default:
                    DashboardView()
                }
                
                // Loading overlay
                if viewModel.isLoading {
                    VStack {
                        Spacer()
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text(viewModel.statusMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding()
                    }
                }
            }
        }
        .environmentObject(viewModel)
        .environmentObject(languageManager)
        .alert(L10n.generalError, isPresented: .constant(viewModel.errorMessage != nil)) {
            Button(L10n.generalOk) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task {
                        await viewModel.updateAllPrices()
                    }
                } label: {
                    Label(L10n.actionUpdatePrices, systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
                .help(L10n.tooltipUpdateAllPrices)
            }
        }
        .onAppear {
            if MacOSSchedulerManager.shared.shouldPromptForAutoRefresh {
                // Small delay so the window finishes rendering before showing the sheet
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showAutoRefreshPrompt = true
                }
            }
        }
        .sheet(isPresented: $showAutoRefreshPrompt) {
            AutoRefreshPromptView()
        }
    }
}

// MARK: - Auto-Refresh Prompt
struct AutoRefreshPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dontAskAgain = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            
            Text(L10n.settingsAutomaticUpdates)
                .font(.title2.bold())
            
            Text(L10n.settingsAutomaticUpdatesDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
            
            // Interval info
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                Text("Default interval: \(MacOSSchedulerManager.shared.selectedInterval.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .padding(.horizontal)
            
            // Don't ask again checkbox
            Toggle(isOn: $dontAskAgain) {
                Text("Don't ask again")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .toggleStyle(.checkbox)
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Not now") {
                    if dontAskAgain {
                        MacOSSchedulerManager.shared.dismissPromptPermanently()
                    }
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                
                Button(L10n.settingsEnable) {
                    MacOSSchedulerManager.shared.install()
                    if dontAskAgain {
                        MacOSSchedulerManager.shared.dismissPromptPermanently()
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(30)
        .frame(width: 400)
    }
}
#endif
