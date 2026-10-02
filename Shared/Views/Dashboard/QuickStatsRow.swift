import SwiftUI
import Charts

// MARK: - Quick Stats Row
struct QuickStatsRow: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    private var statsData: [QuickStatData] {
        computeStats(
            from: viewModel.cachedHoldingsWithQuantity,
            histories: viewModel.cachedHoldingHistories,
            returns: viewModel.cachedHoldingTWR
        )
    }
    
    private func computeStats(
        from allHoldings: [(isin: String, name: String, quantity: Double)],
        histories: [String: [(date: Date, value: Double)]],
        returns: [String: Double]
    ) -> [QuickStatData] {
        var stats: [QuickStatData] = []
        guard !allHoldings.isEmpty else { return stats }
        
        var holdingChanges: [(name: String, change: Double, value: Double)] = []
        for holding in allHoldings {
            let history = histories[holding.isin] ?? []
            if let last = history.last?.value, let changePercent = returns[holding.isin] {
                holdingChanges.append((name: holding.name, change: changePercent, value: last))
            }
        }
        
        // Best Performer
        if let best = holdingChanges.max(by: { $0.change < $1.change }) {
            stats.append(QuickStatData(
                icon: "arrow.up.right.circle.fill",
                iconColor: AppTheme.gain,
                title: L10n.statsBestPerformer,
                value: String(format: "%+.1f%%", best.change),
                detail: best.name
            ))
        }
        
        // Worst Performer
        if let worst = holdingChanges.min(by: { $0.change < $1.change }) {
            stats.append(QuickStatData(
                icon: "arrow.down.right.circle.fill",
                iconColor: AppTheme.loss,
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
        Group {
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
                    .font(.body)
                    .foregroundColor(data.iconColor)
                
                Text(data.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(data.value)
                .font(.headline)
                .lineLimit(1)
            
            Text(data.detail)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 140)
        .padding(12)
        .modifier(GlassEffectFallback(cornerRadius: 16, interactive: false))
    }
}

// MARK: - Previews

#Preview("QuickStatsRow") {
    QuickStatsRow(privacyMode: false)
        .environmentObject(AppViewModel.preview)
        .padding()
}
