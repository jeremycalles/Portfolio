import SwiftUI
import Charts

// MARK: - Dashboard View Mode
enum DashboardViewMode: String, CaseIterable, Identifiable {
    case quadrants
    case holdings
    case accounts
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .quadrants: return L10n.dashboardQuadrants
        case .holdings: return L10n.dashboardHoldings
        case .accounts: return L10n.dashboardAccounts
        }
    }
}

// MARK: - Dashboard View
struct DashboardView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var viewMode: DashboardViewMode = .quadrants
    @State private var privacyMode: Bool = false
    @State private var quadrantGoldMode: Set<Int> = []  // Track which quadrants show gold ounces
    
    private static let lastUpdateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
    
    private static let relativeDateTimeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Pickers row
                HStack(spacing: 32) {
                    // Period Picker (exclude 1 Day for Dashboard)
                    HStack(spacing: 12) {
                        Text(L10n.dashboardComparisonPeriod)
                            .font(.headline)
                        Picker("Period", selection: $viewModel.selectedPeriod) {
                            ForEach(ReportPeriod.allCases.filter { $0 != .oneDay }) { period in
                                Text(period.displayName).tag(period)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 300)
                    }
                    
                    // View Mode Picker
                    HStack(spacing: 12) {
                        Text(L10n.dashboardViewMode)
                            .font(.headline)
                        Picker("View", selection: $viewMode) {
                            ForEach(DashboardViewMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 300)
                    }
                    
                    Spacer()
                    
                    // Privacy Toggle
                    Toggle(isOn: $privacyMode) {
                        Label(L10n.privacyHidden, systemImage: privacyMode ? "eye.slash" : "eye")
                            .font(.headline)
                    }
                    #if os(macOS)
                    .toggleStyle(.checkbox)
                    #endif
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
                
                // Portfolio Summary, Trend, and Pie Chart side by side
                HStack(alignment: .top, spacing: 16) {
                    // Portfolio Totals (hidden in privacy mode)
                    if !privacyMode {
                        GroupBox(L10n.dashboardPortfolioSummary) {
                            let totals = viewModel.getGrandTotalsEUR()
                            let goldTotals = viewModel.getGrandTotalsInGold()
                            let history = viewModel.getPortfolioValueHistory()
                            let goldHistory = viewModel.getGoldOzHistory()
                            
                            // Compute change from history (same as Trend chart)
                            let eurChange: Double? = {
                                guard let first = history.first?.value, let last = history.last?.value, first > 0 else { return nil }
                                return ((last - first) / first) * 100
                            }()
                            let goldChange: Double? = {
                                guard let first = goldHistory.first?.value, let last = goldHistory.last?.value, first > 0 else { return nil }
                                return ((last - first) / first) * 100
                            }()
                            
                            if totals.current == 0 {
                                Text(L10n.dashboardNoHoldings)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                VStack(alignment: .leading, spacing: 12) {
                                    // Top right: same "Last refresh" as Settings (relative) or fallback to latest price date
                                    HStack {
                                        Spacer()
                                        if let lastRefresh = viewModel.getLastRefreshDate() {
                                            Text("\(L10n.summaryLastUpdate) \(Self.relativeDateTimeFormatter.localizedString(for: lastRefresh, relativeTo: Date()))")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        } else if let lastUpdate = viewModel.getLastInstrumentUpdateDate() {
                                            Text("\(L10n.summaryLastUpdate) \(Self.lastUpdateFormatter.string(from: lastUpdate))")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    // EUR Value
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                                            Text("EUR")
                                                .font(.headline)
                                            Text(formatCurrency(totals.current, currency: "EUR"))
                                                .font(.title)
                                                .fontWeight(.bold)
                                        }
                                        
                                        HStack {
                                            if let firstValue = history.first?.value, firstValue > 0 {
                                                Text("\(L10n.summaryFrom) \(formatCurrency(firstValue, currency: "EUR"))")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                
                                                Spacer()
                                                
                                                if let change = eurChange {
                                                    ChangeLabel(change: change)
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Gold Ounces Value
                                    if let gold = goldTotals {
                                        Divider()
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                                Text(L10n.summaryGold)
                                                    .font(.headline)
                                                    .foregroundColor(.yellow)
                                                Text(String(format: "%.2f oz", gold.current))
                                                    .font(.title2)
                                                    .fontWeight(.bold)
                                            }
                                            
                                            HStack {
                                                if let firstGold = goldHistory.first?.value, firstGold > 0 {
                                                    Text("\(L10n.summaryFrom) \(String(format: "%.2f oz", firstGold))")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    
                                                    Spacer()
                                                    
                                                    if let change = goldChange {
                                                        ChangeLabel(change: change)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .padding()
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            }
                        }
                        .frame(minWidth: 280, maxWidth: 280, minHeight: 230, maxHeight: .infinity)
                    }
                    
                    // Portfolio Trend Chart
                    GroupBox(L10n.dashboardPortfolioTrend) {
                        let history = viewModel.getPortfolioValueHistory()
                        let sp500History = viewModel.getSP500ComparisonHistory()
                        let goldHistory = viewModel.getGoldComparisonHistory()
                        let msciWorldHistory = viewModel.getMSCIWorldComparisonHistory()
                        
                        if history.isEmpty {
                            Text(L10n.dashboardNoHistoricalData)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Group {
                                PortfolioTrendChart(
                                    history: history,
                                    sp500History: sp500History.isEmpty ? nil : sp500History,
                                    goldHistory: goldHistory.isEmpty ? nil : goldHistory,
                                    msciWorldHistory: msciWorldHistory.isEmpty ? nil : msciWorldHistory
                                )
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 230, maxHeight: .infinity)
                    
                    // Allocation Pie Chart (for Quadrants or Accounts view mode)
                    if viewMode == .quadrants {
                        GroupBox(L10n.dashboardQuadrantAllocation) {
                            QuadrantPieChart(privacyMode: privacyMode)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(minWidth: 280, maxWidth: 280, minHeight: 230, maxHeight: .infinity)
                    } else if viewMode == .accounts {
                        GroupBox(L10n.dashboardAccountAllocation) {
                            AccountsPieChart(privacyMode: privacyMode)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(minWidth: 280, maxWidth: 280, minHeight: 230, maxHeight: .infinity)
                    }
                }
                .frame(minHeight: 220)
                .padding(.horizontal)
                
                // Conditional view based on mode
                switch viewMode {
                case .quadrants:
                    // Quadrant Trend Charts (2 per row)
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(viewModel.quadrants) { quadrant in
                            let isGoldMode = quadrantGoldMode.contains(quadrant.id)
                            let title = isGoldMode ? "\(quadrant.name) (oz Au)" : quadrant.name
                            
                            GroupBox(title) {
                                let history = isGoldMode
                                    ? viewModel.getQuadrantValueHistoryInGold(quadrantId: quadrant.id)
                                    : viewModel.getQuadrantValueHistory(quadrantId: quadrant.id)
                                
                                if history.isEmpty {
                                    Text(isGoldMode ? L10n.chartNoGoldPriceData : L10n.generalNoData)
                                        .foregroundColor(.secondary)
                                        .frame(height: 150)
                                        .frame(maxWidth: .infinity)
                                } else {
                                    PortfolioTrendChart(history: history, compact: true, unit: isGoldMode ? "oz" : "EUR")
                                        .frame(height: 150)
                                }
                            }
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    let id = quadrant.id
                                    if quadrantGoldMode.contains(id) {
                                        quadrantGoldMode.remove(id)
                                    } else {
                                        quadrantGoldMode.insert(id)
                                    }
                                }
                            }
                            .help(L10n.chartClickToToggle)
                        }
                    }
                    .padding(.horizontal)
                    
                case .holdings:
                    // Holdings Trend Charts (2 per row)
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        let holdings = viewModel.getAllHoldingsWithQuantity()
                        ForEach(holdings, id: \.isin) { holding in
                            GroupBox(holding.name) {
                                let history = viewModel.getHoldingValueHistory(isin: holding.isin, quantity: holding.quantity)
                                
                                if history.isEmpty {
                                    Text(L10n.generalNoData)
                                        .foregroundColor(.secondary)
                                        .frame(height: 150)
                                        .frame(maxWidth: .infinity)
                                } else {
                                    PortfolioTrendChart(history: history, compact: true)
                                        .frame(height: 150)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                case .accounts:
                    // Account Trend Charts (2 per row) - only accounts with data
                    let accountsWithData = viewModel.bankAccounts.filter { account in
                        !viewModel.getAccountValueHistory(accountId: account.id).isEmpty
                    }
                    
                    if accountsWithData.isEmpty {
                        Text(L10n.dashboardNoAccountsWithData)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(accountsWithData) { account in
                                GroupBox(account.displayName) {
                                    let history = viewModel.getAccountValueHistory(accountId: account.id)
                                    PortfolioTrendChart(history: history, compact: true)
                                        .frame(height: 150)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical)
        }
        .navigationTitle(L10n.navDashboard)
    }
}
