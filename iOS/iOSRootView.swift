import SwiftUI
import Charts

let iOSWalkthroughStorageKey = "portfolio_ios_walkthrough_hidden"

// MARK: - iOS Root View with TabView Navigation
struct iOSRootView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedTab = 0
    @State private var showsWalkthrough = false
    @AppStorage("privacyMode") private var privacyMode = false
    @AppStorage(iOSWalkthroughStorageKey) private var hasHiddenWalkthrough = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            dashboardNavigationStack
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
            showsWalkthrough = !hasHiddenWalkthrough
        }
        .fullScreenCover(isPresented: $showsWalkthrough) {
            iOSWalkthroughView {
                showsWalkthrough = false
            }
            .interactiveDismissDisabled()
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

    @ViewBuilder
    private var dashboardNavigationStack: some View {
        if #available(iOS 26.0, *) {
            NavigationStack {
                iOSDashboardView(privacyMode: privacyMode)
                    .navigationTitle(L10n.navDashboard)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItemGroup(placement: .primaryAction) {
                            Button {
                                privacyMode.toggle()
                            } label: {
                                Image(systemName: privacyMode ? "eye.slash.fill" : "eye.fill")
                            }
                            .accessibilityLabel(L10n.settingsPrivacyMode)

                            Button {
                                Task {
                                    await viewModel.startRefreshTask(showCompletionDelay: false).value
                                }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .disabled(viewModel.isLoading)
                            .accessibilityLabel(L10n.actionUpdateAllPrices)
                        }
                    }
            }
        } else {
            NavigationStack {
                iOSDashboardView(privacyMode: privacyMode)
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

// MARK: - iOS Dashboard View
struct iOSDashboardView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    @State private var viewMode: DashboardViewMode = .quadrants
    
    
    var body: some View {
        if #available(iOS 26.0, *) {
            liquidGlassBody
        } else {
            legacyBody
        }
    }

    private var legacyBody: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Enhanced Hero Portfolio Card
                let totals = viewModel.cachedGrandTotalsEUR

                // Period chips sit inside the hero: they drive its change figure,
                // best/worst and the chart below.
                EnhancedPortfolioHeroCard(
                    currentValue: totals.current,
                    previousValue: totals.previous,
                    privacyMode: privacyMode,
                    selectedPeriod: $viewModel.selectedPeriod
                )
                
                // MARK: - Quick Stats Row
                QuickStatsRow()
                
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
                                Text(L10n.dashboardNoDataAvailable)
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
                                investedCapitalHistory: viewModel.cachedInvestedCapitalHistory,
                                transactionEvents: viewModel.cachedTransactionEvents,
                                sp500History: sp500History.isEmpty ? nil : sp500History,
                                goldHistory: goldHistory.isEmpty ? nil : goldHistory,
                                msciWorldHistory: msciWorldHistory.isEmpty ? nil : msciWorldHistory,
                                performancePercent: viewModel.cachedPeriodTWR
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

    @available(iOS 26.0, *)
    private var liquidGlassBody: some View {
        ScrollView {
            VStack(spacing: 16) {
                let totals = viewModel.cachedGrandTotalsEUR

                // Period chips sit inside the hero: they drive its change figure,
                // best/worst and the performance chart.
                EnhancedPortfolioHeroCard(
                    currentValue: totals.current,
                    previousValue: totals.previous,
                    privacyMode: privacyMode,
                    selectedPeriod: $viewModel.selectedPeriod
                )

                QuickStatsRow()

                iOSPortfolioPerformancePanel(privacyMode: privacyMode)

                // View mode only switches the breakdown below, so it lives here.
                iOSDashboardModeBar(selectedMode: $viewMode)

                if viewMode == .quadrants || viewMode == .accounts {
                    EnhancedAllocationRingChart(
                        privacyMode: privacyMode,
                        isQuadrants: viewMode == .quadrants
                    )
                }

                switch viewMode {
                case .quadrants:
                    iOSDashboardQuadrantsSectionEnhanced(privacyMode: privacyMode)
                case .holdings:
                    iOSDashboardHoldingsSectionEnhanced(privacyMode: privacyMode)
                case .accounts:
                    iOSDashboardAccountsSectionEnhanced(privacyMode: privacyMode)
                }

                Spacer(minLength: 24)
            }
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await viewModel.startRefreshTask(showCompletionDelay: false).value
        }
        .overlay {
            if viewModel.isLoading {
                iOSLoadingStatusCapsule(message: viewModel.statusMessage)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.isLoading)
    }
}

@available(iOS 26.0, *)
private struct iOSDashboardModeBar: View {
    @Binding var selectedMode: DashboardViewMode
    @Namespace private var modeAnimation

    var body: some View {
        HStack(spacing: 6) {
            ForEach(DashboardViewMode.allCases) { mode in
                Button {
                    HapticService.impact(.light)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        selectedMode = mode
                    }
                } label: {
                    Label(mode.displayName, systemImage: selectedMode == mode ? "\(mode.icon).fill" : mode.icon)
                        .font(AppTheme.Typography.control)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(selectedMode == mode ? AppTheme.onSelection : .primary)
                        .background {
                            if selectedMode == mode {
                                Capsule()
                                    .fill(AppTheme.selection)
                                    .matchedGeometryEffect(id: "mode", in: modeAnimation)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedMode == mode ? .isSelected : [])
            }
        }
        .padding(6)
        .portfolioGlassSurface(cornerRadius: 22, interactive: true)
        .padding(.horizontal)
    }
}

@available(iOS 26.0, *)
private struct iOSPortfolioPerformancePanel: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.generalPerformance)
                    .font(.headline)
                Spacer()
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)

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
                        Text(L10n.dashboardNoDataAvailable)
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
                        investedCapitalHistory: viewModel.cachedInvestedCapitalHistory,
                        transactionEvents: viewModel.cachedTransactionEvents,
                        sp500History: sp500History.isEmpty ? nil : sp500History,
                        goldHistory: goldHistory.isEmpty ? nil : goldHistory,
                        msciWorldHistory: msciWorldHistory.isEmpty ? nil : msciWorldHistory,
                        performancePercent: viewModel.cachedPeriodTWR,
                        interactive: true,
                        privacyMode: privacyMode
                    )
                    .frame(height: 250)
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
        .portfolioGlassSurface(cornerRadius: 22)
        .padding(.horizontal)
    }
}

@available(iOS 26.0, *)
private struct iOSLoadingStatusCapsule: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(message)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .portfolioGlassSurface(cornerRadius: 16, interactive: true)
    }
}

// MARK: - Previews

#Preview("iOSRootView") {
    iOSRootView()
        .environmentObject(AppViewModel.preview)
        .environmentObject(IOSLockManager.shared)
        .environmentObject(LanguageManager.shared)
}
