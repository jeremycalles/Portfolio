import SwiftUI

let iOSWalkthroughStorageKey = "portfolio_ios_walkthrough_hidden"

struct iOSRootView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @StateObject private var demoMode = DemoModeManager.shared
    @AppStorage("privacyMode") private var privacyMode = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                iOSDashboardView(privacyMode: privacyMode, selectedTab: $selectedTab)
                    .navigationTitle(L10n.designOverview)
                    .navigationBarTitleDisplayMode(.inline)
                    .portfolioPrivacyToolbar()
            }
            .tabItem { Label(L10n.designOverview, systemImage: "chart.line.uptrend.xyaxis") }.tag(0)
            NavigationStack {
                iOSAllHoldingsView(privacyMode: privacyMode)
                    .navigationTitle(L10n.navHoldings)
                    .portfolioPrivacyToolbar()
            }
            .tabItem { Label(L10n.navHoldings, systemImage: "wallet.bifold") }.tag(1)
            NavigationStack {
                iOSQuadrantReportView(privacyMode: privacyMode)
                    .navigationTitle(L10n.designAllocation)
                    .portfolioPrivacyToolbar()
            }
            .tabItem { Label(L10n.designAllocation, systemImage: "chart.pie") }.tag(2)
            NavigationStack {
                iOSSettingsView(privacyMode: $privacyMode)
                    .navigationTitle(L10n.settingsTitle)
                    .portfolioPrivacyToolbar()
            }
            .tabItem { Label(L10n.navSettings, systemImage: "gearshape") }.tag(3)
        }
        .tint(AppTheme.portfolio)
        .safeAreaInset(edge: .top, spacing: 0) {
            if demoMode.isDemoModeEnabled {
                Label(L10n.designDemoBanner, systemImage: "theatermasks")
                    .font(.caption).frame(maxWidth: .infinity).padding(8)
                    .background(AppTheme.surface)
            }
        }
        .onChange(of: demoMode.isDemoModeEnabled) { _, _ in
            Task { await viewModel.refreshAll() }
        }
        .alert(L10n.generalError, isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.dismissError() } }
        )) {
            Button(L10n.generalOk) { viewModel.dismissError() }
        } message: { Text(viewModel.errorMessage ?? "") }
        .refreshResultOverlay(result: viewModel.refreshResult, onDismiss: viewModel.dismissRefreshResult)
    }
}

private struct IOSPrivacyToolbar: ViewModifier {
    @AppStorage("privacyMode") private var privacyMode = false
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { privacyMode.toggle() } label: {
                    Image(systemName: privacyMode ? "eye.slash" : "eye")
                }
                .accessibilityLabel(privacyMode ? L10n.designShowValues : L10n.designHideValues)
                .accessibilityValue(privacyMode ? L10n.designValuesHidden : L10n.designShowValues)
            }
        }
    }
}

extension View {
    func portfolioPrivacyToolbar() -> some View { modifier(IOSPrivacyToolbar()) }
}

struct iOSDashboardView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dynamicTypeSize) private var typeSize
    let privacyMode: Bool
    @Binding var selectedTab: Int
    @State private var showingAdd = false
    @State private var showingBackup = false
    @State private var showingChart = false

    private var details: [HoldingDetail] {
        viewModel.cachedHoldingDetailsByAccount.values.flatMap { $0 }
            .sorted { ($0.currentValueEUR ?? 0) > ($1.currentValueEUR ?? 0) }
    }

    var body: some View {
        ScrollView {
            if viewModel.holdings.isEmpty {
                iOSWalkthroughView(onAdd: { showingAdd = true }, onRestore: { showingBackup = true })
            } else {
                VStack(spacing: 20) {
                    EnhancedPortfolioHeroCard(
                        currentValue: viewModel.cachedGrandTotalsEUR.current,
                        previousValue: viewModel.cachedGrandTotalsEUR.previous,
                        privacyMode: privacyMode,
                        selectedPeriod: $viewModel.selectedPeriod
                    )
                    if details.contains(where: { $0.currentValueEUR == nil }) {
                        NavigationLink {
                            iOSAllHoldingsView(privacyMode: privacyMode, initialFilter: .missingPrice)
                                .navigationTitle(L10n.designReviewPrices)
                        } label: {
                            Label(L10n.designUnavailablePrices, systemImage: "exclamationmark.triangle")
                                .font(.subheadline).foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .portfolioCard()
                        }
                        .buttonStyle(.plain).padding(.horizontal)
                    }
                    performancePanel
                    GoldOilRatioCard().padding(.horizontal)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(L10n.designYourHoldings).font(.headline)
                            Spacer()
                            Button(L10n.designSeeAll) { selectedTab = 1 }.frame(minHeight: 44)
                        }
                        ForEach(Array(details.prefix(3))) { detail in
                            NavigationLink {
                                HoldingDetailView(accountId: detail.accountId, isin: detail.isin, privacyMode: privacyMode)
                            } label: {
                                iOSHoldingRow(detail: detail, privacyMode: privacyMode)
                            }
                            .buttonStyle(.plain)
                            if detail.id != details.prefix(3).last?.id { Divider() }
                        }
                    }
                    .portfolioCard().padding(.horizontal)
                    Button { selectedTab = 2 } label: {
                        HStack {
                            Label(L10n.designAllocation, systemImage: "chart.pie")
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }.frame(minHeight: 44).portfolioCard()
                    }.buttonStyle(.plain).padding(.horizontal)
                    Label(L10n.designStoredLocally, systemImage: "lock.shield")
                        .font(.caption).foregroundStyle(.secondary).padding(.bottom)
                }
                .padding(.top, 8)
            }
        }
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { Task { await viewModel.startRefreshTask(showCompletionDelay: false).value } } label: {
                    if viewModel.isLoading { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                }
                .accessibilityLabel(L10n.actionUpdateAllPrices).disabled(viewModel.isLoading)
                Button { showingAdd = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel(L10n.holdingsAddHolding)
                    .disabled(viewModel.demoMode.isDemoModeEnabled)
            }
        }
        .refreshable { await viewModel.startRefreshTask(showCompletionDelay: false).value }
        .sheet(isPresented: $showingAdd) { AddHoldingSheet() }
        .sheet(isPresented: $showingBackup) { NavigationStack { iOSBackupView() } }
        .sheet(isPresented: $showingChart) {
            NavigationStack {
                ScrollView {
                    PeriodChips(selectedPeriod: $viewModel.selectedPeriod).padding()
                    portfolioChart.frame(height: typeSize.isAccessibilitySize ? 580 : 440)
                }
                .navigationTitle(L10n.designInvestmentReturn)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.generalDone) { showingChart = false } } }
                .portfolioPrivacyToolbar()
            }
        }
    }

    private var performancePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.designInvestmentReturn).font(.headline)
                Spacer()
                Button { showingChart = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                    .frame(minWidth: 44, minHeight: 44).accessibilityLabel(L10n.designExpandChart)
            }.padding(.horizontal, 16)
            if viewModel.cachedPortfolioHistory.isEmpty {
                ContentUnavailableView {
                    Label(L10n.dashboardNoHistoricalData, systemImage: "chart.xyaxis.line")
                } description: { Text(L10n.designNoHistoryAction) } actions: {
                    Button(L10n.designDownloadHistory) {
                        Task { await viewModel.backfillHistorical(period: "1y", interval: "1mo") }
                    }.disabled(viewModel.isLoading)
                }
            } else {
                portfolioChart.frame(height: privacyMode || viewModel.demoMode.isDemoModeEnabled ? 160 : typeSize.isAccessibilitySize ? 430 : 310)
            }
        }.padding(.vertical, 8).background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal)
    }

    private var portfolioChart: some View {
        PortfolioPerformanceChart(privacyMode: privacyMode, startsWithReturn: true)
    }
}

#Preview("iOSRootView") {
    iOSRootView().environmentObject(AppViewModel.preview)
        .environmentObject(IOSLockManager.shared).environmentObject(LanguageManager.shared)
}
