import SwiftUI
import Charts

#if os(macOS)
// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @StateObject private var languageManager = LanguageManager.shared
    @State private var selectedTab = 0
    
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
                
                Menu {
                    Button(L10n.actionBackfill1Year) {
                        Task {
                            await viewModel.backfillHistorical(period: "1y", interval: "1mo")
                        }
                    }
                    Button(L10n.actionBackfill2Years) {
                        Task {
                            await viewModel.backfillHistorical(period: "2y", interval: "1mo")
                        }
                    }
                    Button(L10n.actionBackfill5Years) {
                        Task {
                            await viewModel.backfillHistorical(period: "5y", interval: "1mo")
                        }
                    }
                } label: {
                    Label(L10n.settingsBackfillData, systemImage: "clock.arrow.circlepath")
                }
                .disabled(viewModel.isLoading)
                .help(L10n.tooltipBackfillHistoricalData)
            }
        }
    }
}

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

// MARK: - All Holdings View (Overview)
struct AllHoldingsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var expandedAccounts: Set<Int> = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Period Picker
                HStack(spacing: 12) {
                    Text(L10n.dashboardComparisonPeriod)
                        .font(.headline)
                    Picker("Period", selection: $viewModel.selectedPeriod) {
                        ForEach(ReportPeriod.allCases) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 400)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Summary (EUR)
                let allDetails = getAllHoldingDetails()
                let totalValue = allDetails.compactMap { $0.currentValueEUR }.reduce(0, +)
                let totalPrevious = allDetails.compactMap { $0.previousValueEUR }.reduce(0, +)
                
                GroupBox {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.dashboardTotalPortfolioValue)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(formatCurrency(totalValue, currency: "EUR"))
                                .font(.title)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(L10n.accountsHoldingsCount(allDetails.count))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if totalPrevious > 0 {
                                let change = ((totalValue - totalPrevious) / totalPrevious) * 100
                                ChangeLabel(change: change)
                            }
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                // Holdings grouped by account
                ForEach(viewModel.bankAccounts) { account in
                    let details = viewModel.getHoldingDetails(forAccount: account.id)
                    let accountTotal = details.compactMap { $0.currentValueEUR }.reduce(0, +)
                    let accountPreviousTotal = details.compactMap { $0.previousValueEUR }.reduce(0, +)
                    
                    GroupBox {
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedAccounts.contains(account.id) },
                                set: { isExpanded in
                                    if isExpanded {
                                        expandedAccounts.insert(account.id)
                                    } else {
                                        expandedAccounts.remove(account.id)
                                    }
                                }
                            )
                        ) {
                            if details.isEmpty {
                                Text(L10n.accountsNoHoldingsInAccount)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                VStack(spacing: 0) {
                                    // Header
                                    HStack {
                                        Text(L10n.holdingsInstrument)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(L10n.holdingsQty)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(width: 80, alignment: .trailing)
                                        Text(L10n.holdingsValue)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(width: 120, alignment: .trailing)
                                        Text(L10n.holdingsChange)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(width: 80, alignment: .trailing)
                                    }
                                    .padding(.vertical, 8)
                                    
                                    Divider()
                                    
                                    // Holdings
                                    ForEach(details) { detail in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(detail.instrumentName)
                                                    .font(.body)
                                                    .lineLimit(1)
                                                if let ticker = detail.ticker {
                                                    Text(ticker)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            
                                            Text(formatQuantity(detail.quantity))
                                                .font(.body)
                                                .frame(width: 80, alignment: .trailing)
                                            
                                            if let value = detail.currentValueEUR {
                                                Text(formatCurrency(value, currency: "EUR"))
                                                    .font(.body)
                                                    .frame(width: 120, alignment: .trailing)
                                            } else {
                                                Text(L10n.generalNa)
                                                    .foregroundColor(.secondary)
                                                    .frame(width: 120, alignment: .trailing)
                                            }
                                            
                                            if let change = detail.changePercentEUR {
                                                ChangeLabel(change: change)
                                                    .frame(width: 80, alignment: .trailing)
                                            } else {
                                                Text("—")
                                                    .foregroundColor(.secondary)
                                                    .frame(width: 80, alignment: .trailing)
                                            }
                                        }
                                        .padding(.vertical, 6)
                                        
                                        if detail.id != details.last?.id {
                                            Divider()
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(account.displayName)
                                        .font(.headline)
                                    Text(L10n.accountsHoldingsCount(details.count))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(formatCurrency(accountTotal, currency: "EUR"))
                                        .font(.headline)
                                    if accountPreviousTotal > 0 {
                                        let change = ((accountTotal - accountPreviousTotal) / accountPreviousTotal) * 100
                                        ChangeLabel(change: change)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.vertical)
        }
        .navigationTitle(L10n.navAllHoldings)
        .onAppear {
            // Expand all accounts by default
            expandedAccounts = Set(viewModel.bankAccounts.map { $0.id })
        }
    }
    
    private func getAllHoldingDetails() -> [HoldingDetail] {
        var allDetails: [HoldingDetail] = []
        for account in viewModel.bankAccounts {
            allDetails.append(contentsOf: viewModel.getHoldingDetails(forAccount: account.id))
        }
        return allDetails
    }
}
#endif

// MARK: - Portfolio Trend Chart (series for S&P 500 color scale)
enum PortfolioChartSeries: String, CaseIterable, Plottable {
    case portfolio
    case sp500
    case gold
    case msciWorld
}

struct PortfolioTrendChart: View {
    let history: [(date: Date, value: Double)]
    var sp500History: [(date: Date, value: Double)]? = nil  // Optional S&P 500 comparison (same amount invested)
    var goldHistory: [(date: Date, value: Double)]? = nil   // Optional Gold comparison
    var msciWorldHistory: [(date: Date, value: Double)]? = nil // Optional MSCI World comparison
    var compact: Bool = false
    var unit: String = "EUR"  // "EUR" or "oz" for gold ounces

    private var allValues: [Double] {
        var v = history.map { $0.value }
        if let sp = sp500History { v.append(contentsOf: sp.map { $0.value }) }
        if let gd = goldHistory { v.append(contentsOf: gd.map { $0.value }) }
        if let mw = msciWorldHistory { v.append(contentsOf: mw.map { $0.value }) }
        return v
    }

    private var minValue: Double {
        allValues.min() ?? 0
    }

    private var maxValue: Double {
        allValues.max() ?? 0
    }

    private var valueChange: Double? {
        guard let first = history.first?.value, let last = history.last?.value, first > 0 else {
            return nil
        }
        return ((last - first) / first) * 100
    }

    private var chartColor: Color {
        if let change = valueChange {
            return change >= 0 ? .green : .red
        }
        return .blue
    }

    private var startDate: Date? {
        history.first?.date
    }

    private var endDate: Date? {
        history.last?.date
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = compact ? .short : .medium
        return formatter
    }

    private func formatValue(_ value: Double) -> String {
        if unit == "oz" {
            // Gold ounces format
            if value >= 100 {
                return String(format: "%.1f oz", value)
            } else if value >= 10 {
                return String(format: "%.2f oz", value)
            } else {
                return String(format: "%.3f oz", value)
            }
        } else {
            // Currency format
            return formatCompactCurrency(value)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            // Legend and % on the same line
            let hasSp500 = sp500History != nil && !(sp500History?.isEmpty ?? true)
            let hasGold = goldHistory != nil && !(goldHistory?.isEmpty ?? true)
            let hasMsci = msciWorldHistory != nil && !(msciWorldHistory?.isEmpty ?? true)
            
            if (valueChange != nil) || hasSp500 || hasGold || hasMsci {
                HStack {
                    if hasSp500 || hasGold || hasMsci {
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Circle().fill(chartColor).frame(width: 6, height: 6)
                                Text(L10n.chartPortfolioLabel).font(.caption2).foregroundColor(.secondary)
                            }
                            if hasSp500 {
                                HStack(spacing: 4) {
                                    Circle().fill(Color.orange).frame(width: 6, height: 6)
                                    Text(L10n.chartSp500Comparison).font(.caption2).foregroundColor(.secondary)
                                }
                            }
                            if hasGold {
                                HStack(spacing: 4) {
                                    Circle().fill(Color.yellow).frame(width: 6, height: 6)
                                    Text(L10n.chartGoldComparison).font(.caption2).foregroundColor(.secondary)
                                }
                            }
                            if hasMsci {
                                HStack(spacing: 4) {
                                    Circle().fill(Color.purple).frame(width: 6, height: 6)
                                    Text(L10n.chartMsciWorldComparison).font(.caption2).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    Spacer()
                    if let change = valueChange {
                        HStack(spacing: 2) {
                            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption2)
                            Text(String(format: "%+.2f%%", change))
                                .font(compact ? .caption2 : .caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(chartColor)
                    }
                }
                .padding(.horizontal, compact ? 8 : 16)
            }

            Chart {
                ForEach(Array(history.enumerated()), id: \.offset) { _, item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(by: .value("Series", PortfolioChartSeries.portfolio))
                    .interpolationMethod(.catmullRom)
                    AreaMark(
                        x: .value("Date", item.date),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [chartColor.opacity(0.3), chartColor.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 0))
                }
                if let sp = sp500History, !sp.isEmpty {
                    ForEach(Array(sp.enumerated()), id: \.offset) { _, item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Value", item.value)
                        )
                        .foregroundStyle(by: .value("Series", PortfolioChartSeries.sp500))
                        .interpolationMethod(.catmullRom)
                    }
                }
                if let gd = goldHistory, !gd.isEmpty {
                    ForEach(Array(gd.enumerated()), id: \.offset) { _, item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Value", item.value)
                        )
                        .foregroundStyle(by: .value("Series", PortfolioChartSeries.gold))
                        .interpolationMethod(.catmullRom)
                    }
                }
                if let mw = msciWorldHistory, !mw.isEmpty {
                    ForEach(Array(mw.enumerated()), id: \.offset) { _, item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Value", item.value)
                        )
                        .foregroundStyle(by: .value("Series", PortfolioChartSeries.msciWorld))
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
            .chartForegroundStyleScale([
                PortfolioChartSeries.portfolio: chartColor,
                PortfolioChartSeries.sp500: Color.orange,
                PortfolioChartSeries.gold: Color.yellow,
                PortfolioChartSeries.msciWorld: Color.purple
            ])
            .chartYScale(domain: minValue * 0.98 ... maxValue * 1.02)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(formatValue(doubleValue))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartLegend(.hidden)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(compact ? 8 : 16)
    }
}

// MARK: - Shared Helper Functions

// Helper for compact currency formatting (Shared)
func formatCompactCurrency(_ value: Double) -> String {
    if value >= 1_000_000 {
        return String(format: "%.1fM", value / 1_000_000)
    } else if value >= 1_000 {
        return String(format: "%.0fK", value / 1_000)
    } else {
        return String(format: "%.0f", value)
    }
}

// MARK: - Portfolio Trend Chart (Shared)
struct PortfolioTrendChartShared: View {
    let history: [(date: Date, value: Double)]
    var compact: Bool = false
    var unit: String = "EUR"  // "EUR" or "oz" for gold ounces
    
    private var minValue: Double {
        history.map { $0.value }.min() ?? 0
    }
    
    private var maxValue: Double {
        history.map { $0.value }.max() ?? 0
    }
    
    private var valueChange: Double? {
        guard let first = history.first?.value, let last = history.last?.value, first > 0 else {
            return nil
        }
        return ((last - first) / first) * 100
    }
    
    private var chartColor: Color {
        if let change = valueChange {
            return change >= 0 ? .green : .red
        }
        return .blue
    }
    
    private var startDate: Date? {
        history.first?.date
    }
    
    private var endDate: Date? {
        history.last?.date
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = compact ? .short : .medium
        return formatter
    }
    
    private func formatValue(_ value: Double) -> String {
        if unit == "oz" {
            // Gold ounces format
            if value >= 100 {
                return String(format: "%.1f oz", value)
            } else if value >= 10 {
                return String(format: "%.2f oz", value)
            } else {
                return String(format: "%.3f oz", value)
            }
        } else {
            // Currency format
            return formatCompactCurrency(value)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            // Change percentage only (same line behavior as PortfolioTrendChart)
            if valueChange != nil {
                HStack {
                    Spacer()
                    if let change = valueChange {
                        HStack(spacing: 2) {
                            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption2)
                            Text(String(format: "%+.2f%%", change))
                                .font(compact ? .caption2 : .caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(chartColor)
                    }
                }
                .padding(.horizontal, compact ? 8 : 16)
            }
            
            Chart(history, id: \.date) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Value", item.value)
                )
                .foregroundStyle(chartColor)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Date", item.date),
                    y: .value("Value", item.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [chartColor.opacity(0.3), chartColor.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: minValue * 0.98 ... maxValue * 1.02)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(formatValue(doubleValue))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(compact ? 8 : 16)
    }
}

// MARK: - Quadrant Pie Chart (Shared)
struct QuadrantPieChart: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    var compact: Bool = false
    
    private var quadrantData: [(name: String, value: Double, color: Color)] {
        let report = viewModel.getQuadrantReport()
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .cyan, .yellow, .mint, .indigo, .teal]
        
        var data: [(name: String, value: Double, color: Color)] = []
        
        for (index, item) in report.enumerated() {
            // Sum all currency values for this quadrant (simplified - assumes single currency or converts)
            let totalValue = item.totalValue.values.reduce(0, +)
            if totalValue > 0 {
                let name = item.quadrant?.name ?? "Unassigned"
                let color = colors[index % colors.count]
                data.append((name: name, value: totalValue, color: color))
            }
        }
        
        return data
    }
    
    private var totalValue: Double {
        quadrantData.reduce(0) { $0 + $1.value }
    }
    
    var body: some View {
        VStack(spacing: compact ? 8 : 12) {
            if quadrantData.isEmpty {
                Text(L10n.generalNoData)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Pie Chart
                Chart(quadrantData, id: \.name) { item in
                    SectorMark(
                        angle: .value("Value", item.value),
                        innerRadius: .ratio(compact ? 0.5 : 0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(4)
                }
                .frame(height: compact ? 120 : 150)
                
                // Legend
                if compact {
                    // Compact legend - vertical list with full names
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(quadrantData, id: \.name) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                    if !privacyMode {
                                        Text("\(Int((item.value / totalValue) * 100))%")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                } else {
                    // Full legend
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(quadrantData, id: \.name) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 10, height: 10)
                                Text(item.name)
                                    .font(.caption)
                                Spacer()
                                if !privacyMode {
                                    Text(formatCurrency(item.value, currency: "EUR"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("(\(Int((item.value / totalValue) * 100))%)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                } else {
                                    Text("***")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(compact ? 8 : 12)
    }
}

// MARK: - Accounts Pie Chart (Shared)
struct AccountsPieChart: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    var compact: Bool = false
    
    private var accountData: [(name: String, value: Double, color: Color)] {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .cyan, .yellow, .mint, .indigo, .teal]
        
        var data: [(name: String, value: Double, color: Color)] = []
        
        for (index, account) in viewModel.bankAccounts.enumerated() {
            let details = viewModel.getHoldingDetails(forAccount: account.id)
            // Sum all holdings values for this account
            let totalValue = details.reduce(0.0) { sum, detail in
                sum + (detail.currentPrice ?? 0) * detail.quantity
            }
            if totalValue > 0 {
                let color = colors[index % colors.count]
                data.append((name: account.displayName, value: totalValue, color: color))
            }
        }
        
        return data
    }
    
    private var totalValue: Double {
        accountData.reduce(0) { $0 + $1.value }
    }
    
    var body: some View {
        VStack(spacing: compact ? 8 : 12) {
            if accountData.isEmpty {
                Text(L10n.generalNoData)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Pie Chart
                Chart(accountData, id: \.name) { item in
                    SectorMark(
                        angle: .value("Value", item.value),
                        innerRadius: .ratio(compact ? 0.5 : 0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(4)
                }
                .frame(height: compact ? 120 : 150)
                
                // Legend
                if compact {
                    // Compact legend - vertical list with full names
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(accountData, id: \.name) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                    if !privacyMode {
                                        Text("\(Int((item.value / totalValue) * 100))%")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                } else {
                    // Full legend
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(accountData, id: \.name) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 10, height: 10)
                                Text(item.name)
                                    .font(.caption)
                                Spacer()
                                if !privacyMode {
                                    Text(formatCurrency(item.value, currency: "EUR"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("(\(Int((item.value / totalValue) * 100))%)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                } else {
                                    Text("***")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(compact ? 8 : 12)
    }
}

// MARK: - Change Label (Shared)
struct ChangeLabel: View {
    let change: Double
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)
            Text(String(format: "%+.2f%%", change))
                .font(.caption)
        }
        .foregroundColor(change >= 0 ? .green : .red)
    }
}

// MARK: - Helper Functions
func formatCurrency(_ value: Double, currency: String) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = currency
    formatter.maximumFractionDigits = 2
    return formatter.string(from: NSNumber(value: value)) ?? "\(currency) \(value)"
}

func formatQuantity(_ value: Double) -> String {
    if value == floor(value) {
        return String(format: "%.0f", value)
    } else if value * 10 == floor(value * 10) {
        return String(format: "%.1f", value)
    } else {
        return String(format: "%.4f", value)
    }
}
