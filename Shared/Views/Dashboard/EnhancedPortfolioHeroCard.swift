import SwiftUI

// MARK: - Enhanced Portfolio Hero Card
struct EnhancedPortfolioHeroCard: View {
    @EnvironmentObject var viewModel: AppViewModel
    let currentValue: Double
    let previousValue: Double
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
        if let twr = viewModel.cachedPeriodTWR { return twr }
        guard previousValue > 0 else { return 0 }
        return (change / previousValue) * 100
    }
    
    private var isPositive: Bool {
        if viewModel.cachedPeriodTWR != nil {
            return (viewModel.cachedPeriodTWR ?? 0) >= 0
        }
        return change >= 0
    }
    
    private var goldTotals: (current: Double, previous: Double)? {
        viewModel.cachedGoldTotals
    }
    
    private var goldHistory: [(date: Date, value: Double)] {
        viewModel.cachedGoldOzHistory
    }
    
    private var goldChange: Double? {
        guard let first = goldHistory.first?.value, let last = goldHistory.last?.value else { return nil }
        return last - first
    }
    
    private var goldChangePercent: Double? {
        guard let first = goldHistory.first?.value, let last = goldHistory.last?.value else { return nil }
        return PortfolioHistoryBuilder.percentChange(from: first, to: last)
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
                        Text(L10n.dashboardPortfolioValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        lastUpdateLabel
                    }
                    Spacer()
                }

                valueBlock
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

}

// MARK: - Previews

#Preview("EnhancedPortfolioHeroCard") {
    EnhancedPortfolioHeroCard(currentValue: 13_500, previousValue: 12_500, privacyMode: false)
        .environmentObject(AppViewModel.preview)
        .frame(width: 400)
        .padding()
}
