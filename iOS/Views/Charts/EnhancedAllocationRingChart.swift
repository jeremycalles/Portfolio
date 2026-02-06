import SwiftUI
import Charts

// MARK: - Enhanced Allocation Ring Chart
struct EnhancedAllocationRingChart: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    let isQuadrants: Bool
    
    private var chartData: [(name: String, value: Double, color: Color)] {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .cyan, .yellow, .mint, .indigo, .teal]
        
        if isQuadrants {
            let report = viewModel.cachedQuadrantReport
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
