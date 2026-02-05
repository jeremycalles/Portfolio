import SwiftUI
import Charts
import UniformTypeIdentifiers

// MARK: - Dashboard View Mode
enum iOSDashboardViewMode: String, CaseIterable, Identifiable {
    case quadrants
    case holdings
    case accounts
    
    var id: String { rawValue }
     
    var icon: String {
        switch self {
        case .quadrants: return "square.grid.2x2"
        case .holdings: return "list.bullet"
        case .accounts: return "building.columns"
        }
    }
    
    var displayName: String {
        switch self {
        case .quadrants: return L10n.dashboardQuadrants
        case .holdings: return L10n.dashboardHoldings
        case .accounts: return L10n.dashboardAccounts
        }
    }
}

// MARK: - Enhanced Portfolio Hero Card
struct EnhancedPortfolioHeroCard: View {
    @EnvironmentObject var viewModel: AppViewModel
    let currentValue: Double
    let previousValue: Double
    let sparklineData: [(date: Date, value: Double)]
    let privacyMode: Bool
    @State private var showGoldMode: Bool = false
    
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
    
    private var change: Double {
        currentValue - previousValue
    }
    
    private var changePercent: Double {
        guard previousValue > 0 else { return 0 }
        return (change / previousValue) * 100
    }
    
    private var isPositive: Bool {
        change >= 0
    }
    
    private var goldTotals: (current: Double, previous: Double)? {
        viewModel.getGrandTotalsInGold()
    }
    
    // Use gold history for consistent change calculation (same as Trend chart)
    private var goldHistory: [(date: Date, value: Double)] {
        viewModel.getGoldOzHistory()
    }
    
    private var goldChange: Double? {
        guard let gold = goldTotals,
              let firstGold = goldHistory.first?.value else { return nil }
        return gold.current - firstGold
    }
    
    private var goldChangePercent: Double? {
        guard let gold = goldTotals,
              let firstGold = goldHistory.first?.value, firstGold > 0 else { return nil }
        return ((gold.current - firstGold) / firstGold) * 100
    }
    
    private var isGoldPositive: Bool {
        (goldChange ?? 0) >= 0
    }
    
    private var gradientColors: [Color] {
        if showGoldMode {
            return isGoldPositive 
                ? [Color.green.opacity(0.15), Color.green.opacity(0.05), Color.clear]
                : [Color.red.opacity(0.15), Color.red.opacity(0.05), Color.clear]
        } else {
            return isPositive 
                ? [Color.green.opacity(0.15), Color.green.opacity(0.05), Color.clear]
                : [Color.red.opacity(0.15), Color.red.opacity(0.05), Color.clear]
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if currentValue == 0 {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(L10n.dashboardNoHoldings)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
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
                HStack(alignment: .top, spacing: 16) {
                    // Left: Value and change
                    VStack(alignment: .leading, spacing: 8) {
                        Text(showGoldMode ? L10n.dashboardPortfolioValueGold : L10n.dashboardPortfolioValue)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if privacyMode {
                            Text("••••••")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                        } else if showGoldMode, let gold = goldTotals {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(String(format: "%.2f", gold.current))
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .contentTransition(.numericText())
                                Text("oz")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.yellow)
                            }
                        } else {
                            Text(formatCurrency(currentValue, currency: "EUR"))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .contentTransition(.numericText())
                        }
                        
                        // Change Indicator Pill
                        if !privacyMode {
                            if showGoldMode, let gold = goldTotals, let goldChg = goldChange, let goldChgPct = goldChangePercent, goldHistory.first?.value ?? 0 > 0 {
                                HStack(spacing: 6) {
                                    Image(systemName: isGoldPositive ? "arrow.up.right" : "arrow.down.right")
                                        .font(.system(size: 11, weight: .semibold))
                                    
                                    Text(String(format: "%+.2f oz", goldChg))
                                        .font(.system(size: 13, weight: .semibold))
                                    
                                    Text("(\(String(format: "%+.2f%%", goldChgPct)))")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(isGoldPositive ? .green : .red)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill((isGoldPositive ? Color.green : Color.red).opacity(0.15))
                                )
                            } else if !showGoldMode, previousValue > 0 {
                                HStack(spacing: 6) {
                                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                                        .font(.system(size: 11, weight: .semibold))
                                    
                                    Text("\(isPositive ? "+" : "")\(formatCurrency(change, currency: "EUR"))")
                                        .font(.system(size: 13, weight: .semibold))
                                    
                                    Text("(\(String(format: "%+.2f%%", changePercent)))")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(isPositive ? .green : .red)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill((isPositive ? Color.green : Color.red).opacity(0.15))
                                )
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showGoldMode.toggle()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(
            ZStack {
                // Gradient background based on performance
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Glass material effect
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 6)
        .padding(.horizontal)
    }
}

// MARK: - Mini Sparkline
struct MiniSparkline: View {
    let data: [(date: Date, value: Double)]
    let isPositive: Bool
    
    private var normalizedData: [Double] {
        guard let minVal = data.map({ $0.value }).min(),
              let maxVal = data.map({ $0.value }).max(),
              maxVal > minVal else {
            return data.map { _ in 0.5 }
        }
        return data.map { ($0.value - minVal) / (maxVal - minVal) }
    }
    
    private var chartColor: Color {
        isPositive ? .green : .red
    }
    
    var body: some View {
        Chart(Array(data.enumerated()), id: \.offset) { index, item in
            LineMark(
                x: .value("Index", index),
                y: .value("Value", item.value)
            )
            .foregroundStyle(chartColor)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)
            
            AreaMark(
                x: .value("Index", index),
                y: .value("Value", item.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [chartColor.opacity(0.3), chartColor.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

// MARK: - Quick Stats Row
struct QuickStatsRow: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    
    private var statsData: [QuickStatData] {
        var stats: [QuickStatData] = []
        
        let allHoldings = viewModel.getAllHoldingsWithQuantity()
        guard !allHoldings.isEmpty else { return stats }
        
        // Calculate holding changes
        var holdingChanges: [(name: String, change: Double, value: Double)] = []
        for holding in allHoldings {
            let history = viewModel.getHoldingValueHistory(isin: holding.isin, quantity: holding.quantity)
            if let first = history.first?.value, let last = history.last?.value, first > 0 {
                let changePercent = ((last - first) / first) * 100
                holdingChanges.append((name: holding.name, change: changePercent, value: last))
            }
        }
        
        // Best Performer
        if let best = holdingChanges.max(by: { $0.change < $1.change }) {
            stats.append(QuickStatData(
                icon: "arrow.up.right.circle.fill",
                iconColor: .green,
                title: L10n.statsBestPerformer,
                value: String(format: "%+.1f%%", best.change),
                detail: best.name
            ))
        }
        
        // Worst Performer
        if let worst = holdingChanges.min(by: { $0.change < $1.change }) {
            stats.append(QuickStatData(
                icon: "arrow.down.right.circle.fill",
                iconColor: .red,
                title: L10n.statsWorstPerformer,
                value: String(format: "%+.1f%%", worst.change),
                detail: worst.name
            ))
        }
        
        // Largest Position
        if let largest = holdingChanges.max(by: { $0.value < $1.value }) {
            stats.append(QuickStatData(
                icon: "chart.pie.fill",
                iconColor: .blue,
                title: L10n.statsLargestPosition,
                value: privacyMode ? L10n.privacyHidden : formatCurrency(largest.value, currency: "EUR"),
                detail: largest.name
            ))
        }
        
        // Total Holdings
        stats.append(QuickStatData(
            icon: "list.bullet.rectangle.fill",
            iconColor: .purple,
            title: L10n.statsTotalHoldings,
            value: "\(allHoldings.count)",
            detail: L10n.accountsAcrossAllAccounts
        ))
        
        return stats
    }
    
    var body: some View {
        if !statsData.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(statsData) { stat in
                        QuickStatCard(data: stat)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Quick Stat Data
struct QuickStatData: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let detail: String
}

// MARK: - Quick Stat Card
struct QuickStatCard: View {
    let data: QuickStatData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: data.icon)
                    .font(.system(size: 16))
                    .foregroundColor(data.iconColor)
                
                Text(data.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(data.value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .lineLimit(1)
            
            Text(data.detail)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 140)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Modern Period Selector
struct ModernPeriodSelector: View {
    @Binding var selectedPeriod: ReportPeriod
    let accentColor: Color
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(ReportPeriod.allCases.filter { $0 != .oneDay }) { period in
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedPeriod = period
                    }
                } label: {
                    Text(period.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(selectedPeriod == period ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            if selectedPeriod == period {
                                Capsule()
                                    .fill(accentColor)
                                    .matchedGeometryEffect(id: "periodSelector", in: animation)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }
}

// MARK: - Icon-Based View Mode Selector
struct IconViewModeSelector: View {
    @Binding var selectedMode: iOSDashboardViewMode
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(iOSDashboardViewMode.allCases) { mode in
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedMode = mode
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedMode == mode ? mode.icon + ".fill" : mode.icon)
                            .font(.system(size: 14, weight: .medium))
                        Text(mode.displayName)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(selectedMode == mode ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background {
                        if selectedMode == mode {
                            Capsule()
                                .fill(Color.blue)
                                .matchedGeometryEffect(id: "viewModeSelector", in: animation)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }
}

// MARK: - Enhanced Allocation Ring Chart
struct EnhancedAllocationRingChart: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    let isQuadrants: Bool
    
    private var chartData: [(name: String, value: Double, color: Color)] {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .cyan, .yellow, .mint, .indigo, .teal]
        
        if isQuadrants {
            let report = viewModel.getQuadrantReport()
            var data: [(name: String, value: Double, color: Color)] = []
            for (index, item) in report.enumerated() {
                let totalValue = item.totalValue.values.reduce(0, +)
                if totalValue > 0 {
                    let name = item.quadrant?.name ?? "Unassigned"
                    let color = colors[index % colors.count]
                    data.append((name: name, value: totalValue, color: color))
                }
            }
            return data
        } else {
            var data: [(name: String, value: Double, color: Color)] = []
            for (index, account) in viewModel.bankAccounts.enumerated() {
                let details = viewModel.getHoldingDetails(forAccount: account.id)
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
    }
    
    private var totalValue: Double {
        chartData.reduce(0) { $0 + $1.value }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isQuadrants ? L10n.dashboardQuadrantAllocation : L10n.dashboardAccountAllocation)
                .font(.headline)
                .padding(.horizontal)
            
            if chartData.isEmpty {
                Text(L10n.generalNoData)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                HStack(spacing: 16) {
                    // Ring Chart with center summary
                    ZStack {
                        Chart(chartData, id: \.name) { item in
                            SectorMark(
                                angle: .value("Value", item.value),
                                innerRadius: .ratio(0.65),
                                angularInset: 2
                            )
                            .foregroundStyle(item.color)
                            .cornerRadius(6)
                        }
                        .frame(width: 130, height: 130)
                        
                        // Center summary
                        VStack(spacing: 2) {
                            if privacyMode {
                                Text("•••")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                            } else {
                                Text(formatCompactCurrency(totalValue))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                            }
                            Text("Total")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Legend
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(chartData.prefix(5), id: \.name) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 1) {
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
                        if chartData.count > 5 {
                            Text("+\(chartData.count - 5) more")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
}

// MARK: - Enhanced Trend Card
struct EnhancedTrendCard: View {
    let title: String
    let history: [(date: Date, value: Double)]
    let currentValue: Double?
    let privacyMode: Bool
    var unit: String = "EUR"  // "EUR" or "oz" for gold ounces
    
    private var changePercent: Double? {
        guard let first = history.first?.value,
              let last = history.last?.value,
              first > 0 else { return nil }
        return ((last - first) / first) * 100
    }
    
    private var chartColor: Color {
        if let change = changePercent {
            return change >= 0 ? .green : .red
        }
        return .blue
    }
    
    private func formatValue(_ value: Double) -> String {
        if unit == "oz" {
            if value >= 100 {
                return String(format: "%.1f oz", value)
            } else if value >= 10 {
                return String(format: "%.2f oz", value)
            } else {
                return String(format: "%.3f oz", value)
            }
        } else {
            return formatCurrency(value, currency: "EUR")
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and change badge
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Spacer()
                
                // Change badge
                if let change = changePercent {
                    HStack(spacing: 3) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(String(format: "%.1f%%", abs(change)))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(change >= 0 ? .green : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill((change >= 0 ? Color.green : Color.red).opacity(0.12))
                    )
                }
            }
            
            // Value
            if let value = currentValue {
                if privacyMode {
                    Text("•••")
                        .font(.headline)
                        .foregroundColor(.secondary)
                } else {
                    Text(formatValue(value))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
            }
            
            // Chart
            if history.isEmpty {
                Text(unit == "oz" ? L10n.chartNoGoldPriceData : L10n.generalNoData)
                    .foregroundColor(.secondary)
                    .frame(height: 80)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(history, id: \.date) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(chartColor)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Date", item.date),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [chartColor.opacity(0.2), chartColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)
                .frame(height: 80)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Interactive Portfolio Chart
struct InteractivePortfolioChart: View {
    let history: [(date: Date, value: Double)]
    let isPositive: Bool
    let privacyMode: Bool
    
    @State private var selectedDate: Date?
    @State private var lastHapticDate: Date?
    
    private var minValue: Double {
        history.map { $0.value }.min() ?? 0
    }
    
    private var maxValue: Double {
        history.map { $0.value }.max() ?? 0
    }
    
    private var chartColor: Color {
        isPositive ? .green : .red
    }
    
    /// Find the closest data point to the selected date
    private func findClosestDataPoint(to date: Date) -> (date: Date, value: Double)? {
        guard !history.isEmpty else { return nil }
        return history.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }
    
    /// Trigger haptic feedback
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    var body: some View {
        if privacyMode {
            // Blurred placeholder when privacy mode is on
            ZStack {
                Chart(history, id: \.date) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(.gray.opacity(0.3))
                }
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)
                .blur(radius: 8)
                
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
            }
        } else {
            ZStack(alignment: .top) {
                Chart(history, id: \.date) { item in
                    // Area fill
                    AreaMark(
                        x: .value("Date", item.date),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [chartColor.opacity(0.3), chartColor.opacity(0.05), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    
                    // Line
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(chartColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }
                // Selection rule mark (vertical line)
                .chartOverlay { proxy in
                    if let selectedDate,
                       let dataPoint = findClosestDataPoint(to: selectedDate) {
                        GeometryReader { geometry in
                            if let xPosition = proxy.position(forX: dataPoint.date) {
                                // Vertical rule line
                                Rectangle()
                                    .fill(chartColor.opacity(0.3))
                                    .frame(width: 1)
                                    .position(x: xPosition, y: geometry.size.height / 2)
                                
                                // Point indicator
                                if let yPosition = proxy.position(forY: dataPoint.value) {
                                    Circle()
                                        .fill(chartColor)
                                        .frame(width: 10, height: 10)
                                        .shadow(color: chartColor.opacity(0.5), radius: 4, x: 0, y: 0)
                                        .position(x: xPosition, y: yPosition)
                                    
                                    // Outer ring
                                    Circle()
                                        .stroke(chartColor.opacity(0.3), lineWidth: 2)
                                        .frame(width: 18, height: 18)
                                        .position(x: xPosition, y: yPosition)
                                }
                            }
                        }
                    }
                }
                .chartXSelection(value: $selectedDate)
                .chartYScale(domain: minValue * 0.98 ... maxValue * 1.02)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundStyle(Color.gray.opacity(0.3))
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundStyle(Color.gray.opacity(0.3))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Tooltip annotation popup
                if let selectedDate,
                   let dataPoint = findClosestDataPoint(to: selectedDate) {
                    ChartTooltipView(date: dataPoint.date, value: dataPoint.value, color: chartColor)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: selectedDate)
                }
            }
            .onChange(of: selectedDate) { oldValue, newValue in
                // Trigger haptic when selection changes to a different data point
                if let newValue,
                   let newPoint = findClosestDataPoint(to: newValue) {
                    if lastHapticDate != newPoint.date {
                        triggerHaptic()
                        lastHapticDate = newPoint.date
                    }
                } else if newValue == nil {
                    lastHapticDate = nil
                }
            }
        }
    }
}

// MARK: - Chart Tooltip View
struct ChartTooltipView: View {
    let date: Date
    let value: Double
    let color: Color
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateFormatter.string(from: date))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(formatCurrency(value, currency: "EUR"))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 8)
    }
}

// MARK: - Modern Chart View (Legacy - kept for backward compatibility)
struct ModernChartView: View {
    let history: [(date: Date, value: Double)]
    let isPositive: Bool
    let privacyMode: Bool
    
    private var minValue: Double {
        history.map { $0.value }.min() ?? 0
    }
    
    private var maxValue: Double {
        history.map { $0.value }.max() ?? 0
    }
    
    private var chartColor: Color {
        isPositive ? .green : .red
    }
    
    var body: some View {
        if privacyMode {
            // Blurred placeholder when privacy mode is on
            ZStack {
                Chart(history, id: \.date) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(.gray.opacity(0.3))
                }
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)
                .blur(radius: 8)
                
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
            }
        } else {
            Chart(history, id: \.date) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Value", item.value)
                )
                .foregroundStyle(chartColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Date", item.date),
                    y: .value("Value", item.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [chartColor.opacity(0.3), chartColor.opacity(0.05), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: minValue * 0.98 ... maxValue * 1.02)
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

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
    }
}

// MARK: - iOS Dashboard View
struct iOSDashboardView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    @State private var viewMode: iOSDashboardViewMode = .quadrants
    
    private var portfolioChange: (amount: Double, percent: Double)? {
        let totals = viewModel.getGrandTotalsEUR()
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
                let totals = viewModel.getGrandTotalsEUR()
                let history = viewModel.getPortfolioValueHistory()
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
                    
                    let history = viewModel.getPortfolioValueHistory()
                    let sp500History = viewModel.getSP500ComparisonHistory()
                    let goldHistory = viewModel.getGoldComparisonHistory()
                    let msciWorldHistory = viewModel.getMSCIWorldComparisonHistory()
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
            viewModel.refreshAll()
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

// MARK: - Dashboard Quadrants Section
struct iOSDashboardQuadrantsSection: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    @State private var quadrantGoldMode: Set<Int> = []  // Track which quadrants show gold ounces
    @State private var unassignedGoldMode: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Quadrant Charts
            ForEach(viewModel.quadrants) { quadrant in
                let isGoldMode = quadrantGoldMode.contains(quadrant.id)
                let title = isGoldMode ? "\(quadrant.name) (oz Au)" : quadrant.name
                let history = isGoldMode
                    ? viewModel.getQuadrantValueHistoryInGold(quadrantId: quadrant.id)
                    : viewModel.getQuadrantValueHistory(quadrantId: quadrant.id)
                
                GroupBox(title) {
                    if history.isEmpty {
                        Text(isGoldMode ? L10n.chartNoGoldPriceData : L10n.generalNoData)
                            .foregroundColor(.secondary)
                            .frame(height: 120)
                            .frame(maxWidth: .infinity)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            // Value summary
                            if !privacyMode, let lastValue = history.last?.value {
                                HStack {
                                    if isGoldMode {
                                        Text(String(format: "%.2f oz", lastValue))
                                            .font(.headline)
                                    } else {
                                        Text(formatCurrency(lastValue, currency: "EUR"))
                                            .font(.headline)
                                    }
                                    Spacer()
                                    if let firstValue = history.first?.value, firstValue > 0 {
                                        let change = ((lastValue - firstValue) / firstValue) * 100
                                        iOSChangeLabel(change: change)
                                    }
                                }
                            } else if privacyMode {
                                HStack {
                                    Text("***")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                            
                            PortfolioTrendChartShared(history: history, compact: true, unit: isGoldMode ? "oz" : "EUR")
                                .frame(height: 120)
                        }
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
            }
            
            // Unassigned holdings
            let unassignedHistory = unassignedGoldMode
                ? viewModel.getQuadrantValueHistoryInGold(quadrantId: nil)
                : viewModel.getQuadrantValueHistory(quadrantId: nil)
            if !unassignedHistory.isEmpty || !viewModel.getQuadrantValueHistory(quadrantId: nil).isEmpty {
                let title = unassignedGoldMode ? "Unassigned (oz Au)" : "Unassigned"
                GroupBox(title) {
                    if unassignedHistory.isEmpty {
                        Text(unassignedGoldMode ? L10n.chartNoGoldPriceData : L10n.generalNoData)
                            .foregroundColor(.secondary)
                            .frame(height: 120)
                            .frame(maxWidth: .infinity)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            if !privacyMode, let lastValue = unassignedHistory.last?.value {
                                HStack {
                                    if unassignedGoldMode {
                                        Text(String(format: "%.2f oz", lastValue))
                                            .font(.headline)
                                    } else {
                                        Text(formatCurrency(lastValue, currency: "EUR"))
                                            .font(.headline)
                                    }
                                    Spacer()
                                    if let firstValue = unassignedHistory.first?.value, firstValue > 0 {
                                        let change = ((lastValue - firstValue) / firstValue) * 100
                                        iOSChangeLabel(change: change)
                                    }
                                }
                            } else if privacyMode {
                                HStack {
                                    Text("***")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                            
                            PortfolioTrendChartShared(history: unassignedHistory, compact: true, unit: unassignedGoldMode ? "oz" : "EUR")
                                .frame(height: 120)
                        }
                    }
                }
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        unassignedGoldMode.toggle()
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Dashboard Holdings Section
struct iOSDashboardHoldingsSection: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            let allHoldings = viewModel.getAllHoldingsWithQuantity()
            if allHoldings.isEmpty {
                GroupBox("Holdings") {
                    Text(L10n.dashboardNoHoldings)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(allHoldings, id: \.isin) { holding in
                    GroupBox(holding.name) {
                        let history = viewModel.getHoldingValueHistory(isin: holding.isin, quantity: holding.quantity)
                        // Use EUR-converted value from history (already converted in getHoldingValueHistory)
                        let valueEUR = history.last?.value
                        
                        if history.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    if !privacyMode, let v = valueEUR {
                                        Text(formatCurrency(v, currency: "EUR"))
                                            .font(.headline)
                                    } else if privacyMode {
                                        Text("***")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                Text("\(holding.quantity, specifier: "%.4f") units")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("No chart data")
                                    .foregroundColor(.secondary)
                                    .frame(height: 80)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    if !privacyMode, let v = valueEUR {
                                        Text(formatCurrency(v, currency: "EUR"))
                                            .font(.headline)
                                    } else if privacyMode {
                                        Text("***")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if let firstValue = history.first?.value, let lastValue = history.last?.value, firstValue > 0 {
                                        let change = ((lastValue - firstValue) / firstValue) * 100
                                        iOSChangeLabel(change: change)
                                    }
                                }
                                Text("\(holding.quantity, specifier: "%.4f") units")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                PortfolioTrendChartShared(history: history, compact: true)
                                    .frame(height: 120)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Dashboard Accounts Section
struct iOSDashboardAccountsSection: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            if viewModel.bankAccounts.isEmpty {
                GroupBox("Accounts") {
                    Text(L10n.accountsNoAccounts)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            } else {
                // Only show accounts with data
                let accountsWithData = viewModel.bankAccounts.filter { account in
                    !viewModel.getAccountValueHistory(accountId: account.id).isEmpty
                }
                
                ForEach(accountsWithData) { account in
                    GroupBox(account.displayName) {
                        let history = viewModel.getAccountValueHistory(accountId: account.id)
                        let details = viewModel.getHoldingDetails(forAccount: account.id)
                        let totalValue = details.compactMap { $0.currentValueEUR }.reduce(0, +)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                if !privacyMode {
                                    Text(formatCurrency(totalValue, currency: "EUR"))
                                        .font(.headline)
                                } else {
                                    Text("***")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if let firstValue = history.first?.value, let lastValue = history.last?.value, firstValue > 0 {
                                    let change = ((lastValue - firstValue) / firstValue) * 100
                                    iOSChangeLabel(change: change)
                                }
                            }
                            Text("\(details.count) holdings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            PortfolioTrendChartShared(history: history, compact: true)
                                .frame(height: 120)
                        }
                    }
                }
                
                // Accounts without chart data (just show summary)
                let accountsWithoutData = viewModel.bankAccounts.filter { account in
                    viewModel.getAccountValueHistory(accountId: account.id).isEmpty
                }
                
                if !accountsWithoutData.isEmpty {
                    GroupBox("Other Accounts") {
                        ForEach(accountsWithoutData) { account in
                            let details = viewModel.getHoldingDetails(forAccount: account.id)
                            let totalValue = details.compactMap { $0.currentValueEUR }.reduce(0, +)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(account.displayName)
                                        .font(.subheadline)
                                    Spacer()
                                    if !privacyMode {
                                        Text(formatCurrency(totalValue, currency: "EUR"))
                                            .fontWeight(.medium)
                                    } else {
                                        Text("***")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Text("\(details.count) holdings • No chart data")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                            if account.id != accountsWithoutData.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Enhanced Dashboard Quadrants Section (with EnhancedTrendCard)
struct iOSDashboardQuadrantsSectionEnhanced: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    @State private var quadrantGoldMode: Set<Int> = []  // Track which quadrants show gold ounces
    @State private var unassignedGoldMode: Bool = false
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
            // Quadrant Charts
            ForEach(viewModel.quadrants) { quadrant in
                let isGoldMode = quadrantGoldMode.contains(quadrant.id)
                let history = isGoldMode
                    ? viewModel.getQuadrantValueHistoryInGold(quadrantId: quadrant.id)
                    : viewModel.getQuadrantValueHistory(quadrantId: quadrant.id)
                let currentValue = history.last?.value
                let title = isGoldMode ? "\(quadrant.name) (oz Au)" : quadrant.name
                
                EnhancedTrendCard(
                    title: title,
                    history: history,
                    currentValue: currentValue,
                    privacyMode: privacyMode,
                    unit: isGoldMode ? "oz" : "EUR"
                )
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
            }
            
            // Unassigned holdings
            let unassignedHistory = unassignedGoldMode
                ? viewModel.getQuadrantValueHistoryInGold(quadrantId: nil)
                : viewModel.getQuadrantValueHistory(quadrantId: nil)
            if !unassignedHistory.isEmpty || !viewModel.getQuadrantValueHistory(quadrantId: nil).isEmpty {
                let title = unassignedGoldMode ? "Unassigned (oz Au)" : "Unassigned"
                EnhancedTrendCard(
                    title: title,
                    history: unassignedHistory,
                    currentValue: unassignedHistory.last?.value,
                    privacyMode: privacyMode,
                    unit: unassignedGoldMode ? "oz" : "EUR"
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        unassignedGoldMode.toggle()
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Enhanced Dashboard Holdings Section (with EnhancedTrendCard)
struct iOSDashboardHoldingsSectionEnhanced: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
            let allHoldings = viewModel.getAllHoldingsWithQuantity()
            
            if allHoldings.isEmpty {
                Text(L10n.holdingsNoHoldings)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(allHoldings, id: \.isin) { holding in
                    let history = viewModel.getHoldingValueHistory(isin: holding.isin, quantity: holding.quantity)
                    let valueEUR = history.last?.value
                    
                    EnhancedTrendCard(
                        title: holding.name,
                        history: history,
                        currentValue: valueEUR,
                        privacyMode: privacyMode
                    )
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Enhanced Dashboard Accounts Section (with EnhancedTrendCard)
struct iOSDashboardAccountsSectionEnhanced: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
            if viewModel.bankAccounts.isEmpty {
                Text(L10n.accountsNoAccounts)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                // Show accounts with data
                let accountsWithData = viewModel.bankAccounts.filter { account in
                    !viewModel.getAccountValueHistory(accountId: account.id).isEmpty
                }
                
                ForEach(accountsWithData) { account in
                    let history = viewModel.getAccountValueHistory(accountId: account.id)
                    let details = viewModel.getHoldingDetails(forAccount: account.id)
                    let totalValue = details.compactMap { $0.currentValueEUR }.reduce(0, +)
                    
                    EnhancedTrendCard(
                        title: "\(account.displayName) (\(details.count) holdings)",
                        history: history,
                        currentValue: totalValue,
                        privacyMode: privacyMode
                    )
                }
                
                // Accounts without chart data
                let accountsWithoutData = viewModel.bankAccounts.filter { account in
                    viewModel.getAccountValueHistory(accountId: account.id).isEmpty
                }
                
                ForEach(accountsWithoutData) { account in
                    let details = viewModel.getHoldingDetails(forAccount: account.id)
                    let totalValue = details.compactMap { $0.currentValueEUR }.reduce(0, +)
                    
                    EnhancedTrendCard(
                        title: "\(account.displayName) (\(details.count) holdings)",
                        history: [],
                        currentValue: totalValue,
                        privacyMode: privacyMode
                    )
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - iOS Quadrant Report View
struct iOSQuadrantReportView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    
    var body: some View {
        List {
            // Period Picker
            Section {
                Picker(L10n.generalComparisonPeriod, selection: $viewModel.selectedPeriod) {
                    ForEach(ReportPeriod.allCases) { period in
                        Text(period.displayName).tag(period)
                    }
                }
            }
            
            // Quadrant Reports
            let report = viewModel.getQuadrantReport()
            ForEach(report) { item in
                Section(item.quadrant?.name ?? "Unassigned") {
                    ForEach(item.holdings) { holding in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(holding.instrumentName)
                                    .font(.headline)
                                Spacer()
                                if let change = holding.changePercentEUR {
                                    iOSChangeLabel(change: change)
                                }
                            }
                            
                            HStack {
                                Text("\(holding.quantity, specifier: "%.4f") units")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if !privacyMode, let value = holding.currentValueEUR {
                                    Text(formatCurrency(value, currency: "EUR"))
                                        .fontWeight(.medium)
                                } else if privacyMode {
                                    Text("***")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Section Total (EUR)
                    HStack {
                        Text("Total (EUR)")
                            .fontWeight(.semibold)
                        Spacer()
                        if !privacyMode {
                            Text(formatCurrency(item.totalValueEUR, currency: "EUR"))
                                .fontWeight(.bold)
                        } else {
                            Text("***")
                                .foregroundColor(.secondary)
                        }
                        if let change = item.changePercentEUR {
                            iOSChangeLabel(change: change)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            viewModel.refreshAll()
        }
    }
}

// MARK: - iOS All Holdings View
struct iOSAllHoldingsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    @State private var showingAddHoldingSheet = false
    
    var body: some View {
        List {
            // Period Picker
            Section {
                Picker(L10n.generalComparisonPeriod, selection: $viewModel.selectedPeriod) {
                    ForEach(ReportPeriod.allCases) { period in
                        Text(period.displayName).tag(period)
                    }
                }
            }
            
            // Holdings grouped by account
            ForEach(viewModel.bankAccounts) { account in
                let details = viewModel.getHoldingDetails(forAccount: account.id)
                if !details.isEmpty {
                    Section(account.displayName) {
                        ForEach(details) { holding in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(holding.instrumentName)
                                        .font(.headline)
                                    Spacer()
                                    if let change = holding.changePercentEUR {
                                        iOSChangeLabel(change: change)
                                    }
                                }
                                
                                HStack {
                                    Text("\(holding.quantity, specifier: "%.4f") units")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if !privacyMode, let value = holding.currentValueEUR {
                                        Text(formatCurrency(value, currency: "EUR"))
                                            .fontWeight(.medium)
                                    } else if privacyMode {
                                        Text("***")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.deleteHolding(accountId: account.id, isin: holding.isin)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        
                        // Account Total (EUR)
                        let totalValue = details.compactMap { $0.currentValueEUR }.reduce(0, +)
                        let totalPreviousValue = details.compactMap { $0.previousValueEUR }.reduce(0, +)
                        let changePercent: Double? = totalPreviousValue > 0 ? ((totalValue - totalPreviousValue) / totalPreviousValue) * 100 : nil
                        
                        HStack {
                            Text("Total (EUR)")
                                .fontWeight(.semibold)
                            Spacer()
                            if !privacyMode {
                                Text(formatCurrency(totalValue, currency: "EUR"))
                                    .fontWeight(.bold)
                            } else {
                                Text("***")
                                    .foregroundColor(.secondary)
                            }
                            if let change = changePercent {
                                iOSChangeLabel(change: change)
                            }
                        }
                    }
                }
            }
            
            // Empty state
            if viewModel.holdings.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(L10n.accountsNoHoldingsYet)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Tap + to add your first holding")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            viewModel.refreshAll()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddHoldingSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(viewModel.bankAccounts.isEmpty || viewModel.instruments.isEmpty)
            }
        }
        .sheet(isPresented: $showingAddHoldingSheet) {
            AddHoldingSheet()
        }
    }
}

// MARK: - Add Holding Sheet
struct AddHoldingSheet: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedAccountId: Int?
    @State private var selectedIsin: String?
    @State private var quantityText = ""
    @State private var purchasePriceText = ""
    @State private var purchaseDate = Date()
    @State private var includePurchaseInfo = false
    
    // Locale-aware number formatter
    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        return formatter
    }
    
    private func parseNumber(_ text: String) -> Double? {
        // First try with current locale (handles comma as decimal separator)
        if let number = numberFormatter.number(from: text) {
            return number.doubleValue
        }
        // Fallback: try replacing comma with period for users who type comma on period-locale
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
    
    private var isValid: Bool {
        guard let _ = selectedAccountId,
              let _ = selectedIsin,
              let quantity = parseNumber(quantityText),
              quantity > 0 else {
            return false
        }
        return true
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Account Selection
                Section("Account") {
                    Picker("Select Account", selection: $selectedAccountId) {
                        Text("Select an account").tag(nil as Int?)
                        ForEach(viewModel.bankAccounts) { account in
                            Text(account.displayName).tag(account.id as Int?)
                        }
                    }
                }
                
                // Instrument Selection
                Section("Instrument") {
                    Picker("Select Instrument", selection: $selectedIsin) {
                        Text("Select an instrument").tag(nil as String?)
                        ForEach(viewModel.instruments) { instrument in
                            Text(instrument.displayName).tag(instrument.isin as String?)
                        }
                    }
                }
                
                // Quantity
                Section("Quantity") {
                    TextField("Number of units", text: $quantityText)
                        .keyboardType(.decimalPad)
                }
                
                // Optional Purchase Info
                Section {
                    Toggle("Include Purchase Info", isOn: $includePurchaseInfo)
                    
                    if includePurchaseInfo {
                        DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
                        
                        TextField("Purchase Price (per unit)", text: $purchasePriceText)
                            .keyboardType(.decimalPad)
                    }
                } header: {
                    Text("Purchase Details")
                } footer: {
                    Text("Optional: Track your cost basis for performance calculation")
                }
            }
            .navigationTitle(L10n.holdingsAddHolding)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addHolding()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                // Pre-select first account and instrument if available
                if selectedAccountId == nil, let firstAccount = viewModel.bankAccounts.first {
                    selectedAccountId = firstAccount.id
                }
                if selectedIsin == nil, let firstInstrument = viewModel.instruments.first {
                    selectedIsin = firstInstrument.isin
                }
            }
        }
    }
    
    private func addHolding() {
        guard let accountId = selectedAccountId,
              let isin = selectedIsin,
              let quantity = parseNumber(quantityText) else {
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let purchaseDateStr: String? = includePurchaseInfo ? dateFormatter.string(from: purchaseDate) : nil
        let purchasePrice: Double? = includePurchaseInfo ? parseNumber(purchasePriceText) : nil
        
        viewModel.addHolding(
            accountId: accountId,
            isin: isin,
            quantity: quantity,
            purchaseDate: purchaseDateStr,
            purchasePrice: purchasePrice
        )
        
        dismiss()
    }
}

// MARK: - iOS Instruments View
struct iOSInstrumentsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingAddSheet = false
    @State private var newIsin = ""
    
    var body: some View {
        List {
            ForEach(viewModel.instruments) { instrument in
                NavigationLink {
                    iOSInstrumentDetailView(instrument: instrument)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(instrument.displayName)
                            .font(.headline)
                        HStack {
                            Text(instrument.isin)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            if let ticker = instrument.ticker, ticker != "N/A" {
                                Text(ticker)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    viewModel.deleteInstrument(viewModel.instruments[index].isin)
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                Form {
                    Section("Add Instrument") {
                        TextField("ISIN", text: $newIsin)
                            .textInputAutocapitalization(.characters)
                    }
                }
                .navigationTitle(L10n.instrumentsAddInstrument)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingAddSheet = false
                            newIsin = ""
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            let isinToAdd = newIsin.trimmingCharacters(in: .whitespaces)
                            showingAddSheet = false
                            newIsin = ""
                            if !isinToAdd.isEmpty {
                                Task {
                                    await viewModel.addInstrument(isin: isinToAdd)
                                }
                            }
                        }
                        .disabled(newIsin.isEmpty)
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView(viewModel.statusMessage)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
        }
    }
}

// MARK: - iOS Instrument Detail View
struct iOSInstrumentDetailView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let instrument: Instrument
    @State private var selectedQuadrantId: Int?
    @State private var showingAddPriceSheet = false
    @State private var showingEditPriceSheet = false
    @State private var showingBackfillLogs = false
    @State private var priceToEdit: Price?
    @State private var priceHistory: [Price] = []
    
    var body: some View {
        List {
            Section("Details") {
                LabeledContent("ISIN", value: instrument.isin)
                LabeledContent("Name", value: instrument.name ?? "N/A")
                if let ticker = instrument.ticker {
                    LabeledContent("Ticker", value: ticker)
                }
                if let currency = instrument.currency {
                    LabeledContent("Currency", value: currency)
                }
            }
            
            Section {
                Picker("Quadrant", selection: $selectedQuadrantId) {
                    Text("Unassigned").tag(nil as Int?)
                    ForEach(viewModel.quadrants) { quadrant in
                        Text(quadrant.name).tag(quadrant.id as Int?)
                    }
                }
                .onChange(of: selectedQuadrantId) { _, newValue in
                    if newValue != instrument.quadrantId {
                        viewModel.assignQuadrant(instrumentIsin: instrument.isin, quadrantId: newValue)
                    }
                }
            } header: {
                Text("Quadrant Assignment")
            } footer: {
                Text("Quadrants help organize your portfolio into categories for reporting")
            }
            
            Section {
                if priceHistory.isEmpty {
                    Text("No price history")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(priceHistory, id: \.id) { price in
                        Button {
                            priceToEdit = price
                            showingEditPriceSheet = true
                        } label: {
                            HStack {
                                Text(price.date)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(formatCurrency(price.value, currency: instrument.currency ?? "EUR"))
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.deletePrice(isin: instrument.isin, date: price.date)
                                refreshPriceHistory()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Price History")
                    Spacer()
                    Menu {
                        Button("1 Month (Daily)") {
                            Task {
                                await viewModel.backfillSingleInstrument(instrument, period: "1mo", interval: "1d")
                                refreshPriceHistory()
                                showingBackfillLogs = true
                            }
                        }
                        Button("1 Year (Monthly)") {
                            Task {
                                await viewModel.backfillSingleInstrument(instrument, period: "1y", interval: "1mo")
                                refreshPriceHistory()
                                showingBackfillLogs = true
                            }
                        }
                        Button("2 Years (Monthly)") {
                            Task {
                                await viewModel.backfillSingleInstrument(instrument, period: "2y", interval: "1mo")
                                refreshPriceHistory()
                                showingBackfillLogs = true
                            }
                        }
                        Button("5 Years (Monthly)") {
                            Task {
                                await viewModel.backfillSingleInstrument(instrument, period: "5y", interval: "1mo")
                                refreshPriceHistory()
                                showingBackfillLogs = true
                            }
                        }
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.accentColor)
                    }
                    .disabled(viewModel.isLoading)
                    
                    Button {
                        showingAddPriceSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .navigationTitle(instrument.displayName)
        .listStyle(.insetGrouped)
        .onAppear {
            selectedQuadrantId = instrument.quadrantId
            refreshPriceHistory()
        }
        .sheet(isPresented: $showingAddPriceSheet) {
            iOSPriceEditorSheet(
                instrument: instrument,
                existingPrice: nil,
                onSave: { date, value, currency in
                    viewModel.addManualPrice(isin: instrument.isin, date: date, value: value, currency: currency)
                    refreshPriceHistory()
                }
            )
        }
        .sheet(isPresented: $showingEditPriceSheet) {
            if let price = priceToEdit {
                iOSPriceEditorSheet(
                    instrument: instrument,
                    existingPrice: price,
                    onSave: { date, value, currency in
                        // Delete old price if date changed, then add new
                        if date != price.date {
                            viewModel.deletePrice(isin: instrument.isin, date: price.date)
                        }
                        viewModel.addManualPrice(isin: instrument.isin, date: date, value: value, currency: currency)
                        refreshPriceHistory()
                    }
                )
            }
        }
        .sheet(isPresented: $showingBackfillLogs) {
            iOSBackfillLogsSheet(logs: viewModel.backfillLogs)
        }
    }
    
    private func refreshPriceHistory() {
        priceHistory = viewModel.getPriceHistory(forIsin: instrument.isin)
    }
}

// MARK: - iOS Backfill Logs Sheet
struct iOSBackfillLogsSheet: View {
    let logs: [String]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(logs.enumerated()), id: \.offset) { _, log in
                        if log.isEmpty {
                            Spacer().frame(height: 12)
                        } else {
                            Text(log)
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundColor(logColor(for: log))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("Backfill Logs")
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
    
    private func logColor(for log: String) -> Color {
        if log.contains("✓") || log.contains("complete") {
            return .green
        } else if log.contains("⚠️") || log.contains("Skipped") || log.contains("No data returned") {
            return .orange
        } else if log.contains("Error") || log.contains("error") {
            return .red
        } else if log.starts(with: "  •") {
            return .secondary
        }
        return .primary
    }
}

// MARK: - iOS Price Editor Sheet
struct iOSPriceEditorSheet: View {
    let instrument: Instrument
    let existingPrice: Price?
    let onSave: (String, Double, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date
    @State private var priceText: String
    @State private var selectedCurrency: String
    
    private let currencies = ["EUR", "USD", "GBP", "CHF", "JPY"]
    
    // Locale-aware number formatter
    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        return formatter
    }
    
    private func parseNumber(_ text: String) -> Double? {
        // First try with current locale (handles comma as decimal separator)
        if let number = numberFormatter.number(from: text) {
            return number.doubleValue
        }
        // Fallback: try replacing comma with period
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
    
    init(instrument: Instrument, existingPrice: Price?, onSave: @escaping (String, Double, String) -> Void) {
        self.instrument = instrument
        self.existingPrice = existingPrice
        self.onSave = onSave
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let price = existingPrice {
            _selectedDate = State(initialValue: formatter.date(from: price.date) ?? Date())
            _priceText = State(initialValue: String(format: "%.4f", price.value))
            _selectedCurrency = State(initialValue: price.currency ?? instrument.currency ?? "EUR")
        } else {
            _selectedDate = State(initialValue: Date())
            _priceText = State(initialValue: "")
            _selectedCurrency = State(initialValue: instrument.currency ?? "EUR")
        }
    }
    
    private var isValid: Bool {
        guard let value = parseNumber(priceText), value > 0 else { return false }
        return true
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Price Details") {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    
                    TextField("Price", text: $priceText)
                        .keyboardType(.decimalPad)
                    
                    Picker("Currency", selection: $selectedCurrency) {
                        ForEach(currencies, id: \.self) { currency in
                            Text(currency).tag(currency)
                        }
                    }
                }
                
                Section {
                    HStack {
                        Text("Instrument")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(instrument.displayName)
                            .lineLimit(1)
                    }
                }
            }
            .navigationTitle(existingPrice == nil ? "Add Price" : "Edit Price")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingPrice == nil ? "Add" : "Save") {
                        if let value = parseNumber(priceText) {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd"
                            let dateString = formatter.string(from: selectedDate)
                            onSave(dateString, value, selectedCurrency)
                            dismiss()
                        }
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

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
struct iOSChangeLabel: View {
    let change: Double
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)
            Text(String(format: "%.2f%%", abs(change)))
                .font(.caption)
        }
        .foregroundColor(change >= 0 ? .green : .red)
    }
}
