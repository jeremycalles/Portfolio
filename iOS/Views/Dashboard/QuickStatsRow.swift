import SwiftUI
import Charts

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
