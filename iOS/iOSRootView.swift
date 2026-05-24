import SwiftUI
import Charts

// MARK: - iOS Root View with TabView Navigation
struct iOSRootView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedTab = 0
    @AppStorage("privacyMode") private var privacyMode = false
    
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
            Task { await viewModel.refreshAll() }
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

    @available(iOS 26.0, *)
    private var liquidGlassBody: some View {
        ScrollView {
            VStack(spacing: 16) {
                let totals = viewModel.cachedGrandTotalsEUR
                let history = viewModel.cachedPortfolioHistory
                let sparklineData = Array(history.suffix(20))
                let previousFromHistory = history.first?.value ?? 0

                EnhancedPortfolioHeroCard(
                    currentValue: totals.current,
                    previousValue: previousFromHistory,
                    sparklineData: sparklineData,
                    privacyMode: privacyMode
                )

                QuickStatsRow(privacyMode: privacyMode)

                iOSDashboardGlassControlBar(
                    selectedPeriod: $viewModel.selectedPeriod,
                    selectedMode: $viewMode,
                    accentColor: accentColor
                )

                iOSPortfolioPerformancePanel(privacyMode: privacyMode)

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
private struct iOSDashboardGlassControlBar: View {
    @Binding var selectedPeriod: ReportPeriod
    @Binding var selectedMode: DashboardViewMode
    let accentColor: Color
    @Namespace private var periodAnimation
    @Namespace private var modeAnimation

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(ReportPeriod.allCases.filter { $0 != .oneDay }) { period in
                    Button {
                        HapticService.impact(.light)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            selectedPeriod = period
                        }
                    } label: {
                        Text(period.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundStyle(selectedPeriod == period ? .white : .primary)
                            .background {
                                if selectedPeriod == period {
                                    Capsule()
                                        .fill(accentColor.gradient)
                                        .matchedGeometryEffect(id: "period", in: periodAnimation)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 6) {
                ForEach(DashboardViewMode.allCases) { mode in
                    Button {
                        HapticService.impact(.light)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            selectedMode = mode
                        }
                    } label: {
                        Label(mode.displayName, systemImage: selectedMode == mode ? "\(mode.icon).fill" : mode.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundStyle(selectedMode == mode ? .white : .primary)
                            .background {
                                if selectedMode == mode {
                                    Capsule()
                                        .fill(Color.accentColor.gradient)
                                        .matchedGeometryEffect(id: "mode", in: modeAnimation)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
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
                        sp500History: sp500History.isEmpty ? nil : sp500History,
                        goldHistory: goldHistory.isEmpty ? nil : goldHistory,
                        msciWorldHistory: msciWorldHistory.isEmpty ? nil : msciWorldHistory,
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
