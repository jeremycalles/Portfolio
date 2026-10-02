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
        viewModel.cachedPeriodGainEUR ?? (currentValue - previousValue)
    }
    
    private var changePercent: Double {
        if let twr = viewModel.cachedPeriodTWR { return twr }
        guard previousValue > 0 else { return 0 }
        return (change / previousValue) * 100
    }

    /// Arrow and euro amount follow the holdings change. The percent keeps its own sign.
    private var euroIsPositive: Bool {
        change >= 0
    }

    private var percentIsPositive: Bool {
        changePercent >= 0
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
                ? [AppTheme.gain.opacity(0.15), AppTheme.gain.opacity(0.05), Color.clear]
                : [AppTheme.loss.opacity(0.15), AppTheme.loss.opacity(0.05), Color.clear]
        } else {
            return euroIsPositive
                ? [AppTheme.gain.opacity(0.15), AppTheme.gain.opacity(0.05), Color.clear]
                : [AppTheme.loss.opacity(0.15), AppTheme.loss.opacity(0.05), Color.clear]
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
                .font(.largeTitle)
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
                    .font(.largeTitle.bold())
            } else if showGoldMode, let gold = goldTotals {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.2f", gold.current))
                        .font(.largeTitle.bold())
                        .contentTransition(.numericText())
                    Text("oz")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.yellow)
                }
            } else {
                Text(formatCurrency(currentValue, currency: "EUR"))
                    .font(.largeTitle.bold())
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
                    euroPositive: isGoldPositive,
                    percentPositive: isGoldPositive,
                    amount: String(format: "%+.2f oz", goldChg),
                    percent: String(format: "%+.2f%%", goldChgPct)
                )
            } else if !showGoldMode, previousValue > 0 {
                changePill(
                    euroPositive: euroIsPositive,
                    percentPositive: percentIsPositive,
                    amount: "\(euroIsPositive ? "+" : "")\(formatCurrency(change, currency: "EUR"))",
                    percent: String(format: "%+.2f%%", changePercent)
                )
            }
        }
    }

    private func changePill(euroPositive: Bool, percentPositive: Bool, amount: String, percent: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: euroPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2.weight(.semibold))
                .foregroundColor(euroPositive ? AppTheme.gain : AppTheme.loss)
            Text(amount)
                .font(.caption.weight(.semibold))
                .foregroundColor(euroPositive ? AppTheme.gain : AppTheme.loss)
            Text("(\(percent))")
                .font(.caption.weight(.medium))
                .foregroundColor(percentPositive ? AppTheme.gain : AppTheme.loss)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill((euroPositive ? AppTheme.gain : AppTheme.loss).opacity(0.15))
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
