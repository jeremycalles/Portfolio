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
        VStack(spacing: 10) {
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
                // Title row: "Valeur du portefeuille" left, "Mis à jour" right
                HStack {
                    Text(showGoldMode ? L10n.dashboardPortfolioValueGold : L10n.dashboardPortfolioValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                .frame(maxWidth: .infinity, alignment: .leading)
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
