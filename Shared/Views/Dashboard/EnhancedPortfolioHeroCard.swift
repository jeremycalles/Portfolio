import SwiftUI
import Charts

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
        viewModel.cachedGoldTotals
    }
    
    private var goldHistory: [(date: Date, value: Double)] {
        viewModel.cachedGoldOzHistory
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
        if #available(iOS 26.0, *) {
            liquidGlassBody
        } else {
            legacyBody
        }
    }

    private var legacyBody: some View {
        VStack(spacing: 10) {
            if currentValue == 0 {
                emptyState
            } else {
                // Title row: "Valeur du portefeuille" left, "Mis à jour" right
                HStack {
                    Text(showGoldMode ? L10n.dashboardPortfolioValueGold : L10n.dashboardPortfolioValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    lastUpdateLabel
                }
                valueBlock
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showGoldMode.toggle()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .modifier(GlassEffectFallback(cornerRadius: 24, interactive: true))
        .padding(.horizontal)
    }

    @available(iOS 26.0, *)
    private var liquidGlassBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            if currentValue == 0 {
                emptyState
            } else {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(showGoldMode ? L10n.dashboardPortfolioValueGold : L10n.dashboardPortfolioValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        lastUpdateLabel
                    }
                    Spacer()
                    currencyModeControl
                }

                ZStack(alignment: .bottomTrailing) {
                    if !displayedSparklineData.isEmpty {
                        sparkline
                            .frame(height: 76)
                            .opacity(0.45)
                            .padding(.leading, 120)
                            .padding(.top, 10)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        valueBlock
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        )
        .portfolioGlassSurface(cornerRadius: 24, interactive: true)
        .padding(.horizontal)
    }

    private var emptyState: some View {
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
    }

    private var lastUpdateLabel: some View {
        Group {
            if let lastRefresh = viewModel.getLastRefreshDate() {
                Text("\(L10n.summaryLastUpdate) \(Self.relativeDateTimeFormatter.localizedString(for: lastRefresh, relativeTo: Date()))")
            } else if let lastUpdate = viewModel.lastInstrumentUpdateDate {
                Text("\(L10n.summaryLastUpdate) \(Self.lastUpdateFormatter.string(from: lastUpdate))")
            }
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }

    private var valueBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            if !privacyMode {
                changeIndicator
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var changeIndicator: some View {
        Group {
            if showGoldMode, goldTotals != nil, let goldChg = goldChange, let goldChgPct = goldChangePercent, goldHistory.first?.value ?? 0 > 0 {
                changePill(
                    isPositive: isGoldPositive,
                    amount: String(format: "%+.2f oz", goldChg),
                    percent: String(format: "%+.2f%%", goldChgPct)
                )
            } else if !showGoldMode, previousValue > 0 {
                changePill(
                    isPositive: isPositive,
                    amount: "\(isPositive ? "+" : "")\(formatCurrency(change, currency: "EUR"))",
                    percent: String(format: "%+.2f%%", changePercent)
                )
            }
        }
    }

    private func changePill(isPositive: Bool, amount: String, percent: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 11, weight: .semibold))
            Text(amount)
                .font(.system(size: 13, weight: .semibold))
            Text("(\(percent))")
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

    @available(iOS 26.0, *)
    private var currencyModeControl: some View {
        HStack(spacing: 4) {
            heroModeButton(title: "EUR", systemImage: "eurosign", selected: !showGoldMode) {
                showGoldMode = false
            }
            heroModeButton(title: "Au", systemImage: "circle.hexagongrid.fill", selected: showGoldMode) {
                showGoldMode = true
            }
            .disabled(goldTotals == nil)
            .opacity(goldTotals == nil ? 0.45 : 1)
        }
        .padding(4)
        .portfolioGlassSurface(cornerRadius: 18, interactive: true)
    }

    @available(iOS 26.0, *)
    private func heroModeButton(title: String, systemImage: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticService.impact(.light)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                action()
            }
        } label: {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 34, height: 30)
                .foregroundStyle(selected ? .white : .primary)
                .background {
                    if selected {
                        Capsule()
                            .fill((showGoldMode ? Color.yellow : Color.accentColor).gradient)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var displayedSparklineData: [(date: Date, value: Double)] {
        showGoldMode ? goldHistory.suffix(20).map { $0 } : sparklineData
    }

    @available(iOS 26.0, *)
    private var sparkline: some View {
        Chart(displayedSparklineData, id: \.date) { item in
            LineMark(
                x: .value("Date", item.date),
                y: .value("Value", item.value)
            )
            .foregroundStyle(showGoldMode ? Color.yellow : (isPositive ? Color.green : Color.red))
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Date", item.date),
                y: .value("Value", item.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [(showGoldMode ? Color.yellow : (isPositive ? Color.green : Color.red)).opacity(0.18), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
        .chartYAxis(.hidden)
        .chartXAxis(.hidden)
    }
}

// MARK: - Previews

#Preview("EnhancedPortfolioHeroCard") {
    let today = Date()
    let sparkline: [(date: Date, value: Double)] = (0..<30).reversed().compactMap { i in
        guard let date = Calendar.current.date(byAdding: .day, value: -i, to: today) else { return nil }
        return (date: date, value: 12_500 * (1 + Double(30 - i) / 30.0 * 0.08))
    }
    EnhancedPortfolioHeroCard(currentValue: 13_500, previousValue: 12_500, sparklineData: sparkline, privacyMode: false)
        .environmentObject(AppViewModel.preview)
        .frame(width: 400)
        .padding()
}
