import SwiftUI

// MARK: - Quick Stats Row
struct QuickStatsRow: View {
    @EnvironmentObject var viewModel: AppViewModel
    private var statsData: [QuickStatData] {
        computeStats(
            from: viewModel.cachedHoldingsWithQuantity,
            returns: viewModel.cachedHoldingTWR
        )
    }
    
    private func computeStats(
        from allHoldings: [(isin: String, name: String, quantity: Double)],
        returns: [String: Double]
    ) -> [QuickStatData] {
        var stats: [QuickStatData] = []
        guard !allHoldings.isEmpty else { return stats }
        
        var holdingChanges: [(name: String, change: Double)] = []
        for holding in allHoldings {
            if let changePercent = returns[holding.isin] {
                holdingChanges.append((name: holding.name, change: changePercent))
            }
        }
        
        // Best Performer
        if let best = holdingChanges.max(by: { $0.change < $1.change }) {
            stats.append(QuickStatData(
                // Sign decides the arrow: the best holding can still be down.
                icon: best.change >= 0 ? "arrow.up.right" : "arrow.down.right",
                iconColor: AppTheme.changeColor(best.change),
                title: L10n.statsBestPerformer,
                value: formatPercentChange(best.change, fractionDigits: 1),
                detail: best.name
            ))
        }
        
        // Worst Performer
        if let worst = holdingChanges.min(by: { $0.change < $1.change }) {
            stats.append(QuickStatData(
                // Sign decides the arrow: the best holding can still be down.
                icon: worst.change >= 0 ? "arrow.up.right" : "arrow.down.right",
                iconColor: AppTheme.changeColor(worst.change),
                title: L10n.statsWorstPerformer,
                value: formatPercentChange(worst.change, fractionDigits: 1),
                detail: worst.name
            ))
        }
        
        return stats
    }
    
    var body: some View {
        Group {
            if !statsData.isEmpty {
                HStack(alignment: .top, spacing: 12) {
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
/// Mirrors the hero card hierarchy: title → value → accent row.
struct QuickStatCard: View {
    let data: QuickStatData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(data.title)
                .font(AppTheme.Typography.label)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            
            Text(data.value)
                .font(AppTheme.Typography.value)
                .foregroundStyle(data.iconColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            HStack(spacing: 6) {
                Image(systemName: data.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(data.iconColor)
                
                Text(data.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.large)
        .modifier(GlassEffectFallback(cornerRadius: AppTheme.Radius.card, interactive: false))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#Preview("QuickStatsRow") {
    QuickStatsRow()
        .environmentObject(AppViewModel.preview)
        .padding()
}
