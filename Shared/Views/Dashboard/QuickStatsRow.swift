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
                icon: "arrow.up.right",
                iconColor: AppTheme.gain,
                title: L10n.statsBestPerformer,
                value: String(format: "%+.1f%%", best.change),
                detail: best.name
            ))
        }
        
        // Worst Performer
        if let worst = holdingChanges.min(by: { $0.change < $1.change }) {
            stats.append(QuickStatData(
                icon: "arrow.down.right",
                iconColor: AppTheme.loss,
                title: L10n.statsWorstPerformer,
                value: String(format: "%+.1f%%", worst.change),
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
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)
            
            Text(data.value)
                .font(.title3.bold())
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
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .modifier(GlassEffectFallback(cornerRadius: 16, interactive: false))
    }
}

// MARK: - Previews

#Preview("QuickStatsRow") {
    QuickStatsRow()
        .environmentObject(AppViewModel.preview)
        .padding()
}
