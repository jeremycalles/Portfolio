import SwiftUI
import Charts
import UniformTypeIdentifiers

// MARK: - iOS Root View with TabView Navigation
struct iOSRootView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedTab = 0
    @AppStorage("privacyMode") private var privacyMode = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            NavigationStack {
                iOSDashboardView(privacyMode: privacyMode)
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label(L10n.navDashboard, systemImage: "chart.pie.fill")
            }
            .tag(0)
            
            // Reports Tab
            NavigationStack {
                iOSQuadrantReportView(privacyMode: privacyMode)
                    .navigationTitle(L10n.navReports)
            }
            .tabItem {
                Label(L10n.navReports, systemImage: "square.grid.2x2.fill")
            }
            .tag(1)
            
            // Holdings Tab
            NavigationStack {
                iOSAllHoldingsView(privacyMode: privacyMode)
                    .navigationTitle(L10n.navHoldings)
            }
            .tabItem {
                Label(L10n.navHoldings, systemImage: "list.bullet.rectangle.fill")
            }
            .tag(2)
            
            // Instruments Tab
            NavigationStack {
                iOSInstrumentsView()
                    .navigationTitle(L10n.navInstruments)
            }
            .tabItem {
                Label(L10n.navInstruments, systemImage: "doc.text.fill")
            }
            .tag(3)
            
            // Settings Tab
            NavigationStack {
                iOSSettingsView(privacyMode: $privacyMode)
                    .navigationTitle(L10n.settingsTitle)
            }
            .tabItem {
                Label(L10n.navSettings, systemImage: "gear")
            }
            .tag(4)
        }
        .onAppear {
            viewModel.refreshAll()
        }
        .alert(L10n.generalError, isPresented: .constant(viewModel.errorMessage != nil)) {
            Button(L10n.generalOk) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .refreshResultOverlay(result: viewModel.refreshResult, onDismiss: { viewModel.dismissRefreshResult() })
    }
}

// MARK: - iOS Dashboard View
struct iOSDashboardView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    @State private var viewMode: DashboardViewMode = .quadrants
    
    private var portfolioChange: (amount: Double, percent: Double)? {
        let totals = viewModel.cachedGrandTotalsEUR
        guard totals.previous > 0 else { return nil }
        let amount = totals.current - totals.previous
        let percent = (amount / totals.previous) * 100
        return (amount, percent)
    }
    
    private var isPositiveChange: Bool {
        (portfolioChange?.percent ?? 0) >= 0
    }
    
    private var accentColor: Color {
        isPositiveChange ? .green : .red
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Enhanced Hero Portfolio Card
                let totals = viewModel.cachedGrandTotalsEUR
                let history = viewModel.cachedPortfolioHistory
                let sparklineData = Array(history.suffix(20))
                // Use first value from history for change calculation (consistent with Trend chart)
                let previousFromHistory = history.first?.value ?? 0
                
                EnhancedPortfolioHeroCard(
                    currentValue: totals.current,
                    previousValue: previousFromHistory,
                    sparklineData: sparklineData,
                    privacyMode: privacyMode
                )
                
                // MARK: - Quick Stats Row
                QuickStatsRow(privacyMode: privacyMode)
                
                // MARK: - Modern Period Selector
                ModernPeriodSelector(
                    selectedPeriod: $viewModel.selectedPeriod,
                    accentColor: accentColor
                )
                
                // MARK: - Portfolio Trend Chart (Total Performance) – same as macOS
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.generalPerformance)
                        .font(.headline)
                        .padding(.horizontal)
                    
                    let history = viewModel.cachedPortfolioHistory
                    let sp500History = viewModel.cachedSP500History
                    let goldHistory = viewModel.cachedGoldHistory
                    let msciWorldHistory = viewModel.cachedMSCIWorldHistory
                    if history.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "chart.xyaxis.line")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary.opacity(0.5))
                                Text("No data available")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .frame(height: 200)
                    } else {
                        ZStack {
                            PortfolioTrendChart(
                                history: history,
                                sp500History: sp500History.isEmpty ? nil : sp500History,
                                goldHistory: goldHistory.isEmpty ? nil : goldHistory,
                                msciWorldHistory: msciWorldHistory.isEmpty ? nil : msciWorldHistory
                            )
                            .frame(height: 250)
                            .padding(.horizontal)
                            .blur(radius: privacyMode ? 8 : 0)
                            if privacyMode {
                                Image(systemName: "eye.slash.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
                )
                .padding(.horizontal)
                
                // MARK: - Icon-Based View Mode Selector
                IconViewModeSelector(selectedMode: $viewMode)
                
                // MARK: - Enhanced Allocation Ring Chart
                if viewMode == .quadrants || viewMode == .accounts {
                    EnhancedAllocationRingChart(
                        privacyMode: privacyMode,
                        isQuadrants: viewMode == .quadrants
                    )
                }
                
                // MARK: - Content based on view mode with Enhanced Trend Cards
                switch viewMode {
                case .quadrants:
                    iOSDashboardQuadrantsSectionEnhanced(privacyMode: privacyMode)
                case .holdings:
                    iOSDashboardHoldingsSectionEnhanced(privacyMode: privacyMode)
                case .accounts:
                    iOSDashboardAccountsSectionEnhanced(privacyMode: privacyMode)
                }
                
                Spacer(minLength: 20)
            }
            .padding(.top, 0)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await viewModel.startRefreshTask(showCompletionDelay: false).value
        }
        .overlay {
            if viewModel.isLoading {
                VStack {
                    ProgressView()
                    Text(viewModel.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
        }
    }
}
