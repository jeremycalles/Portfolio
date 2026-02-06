import SwiftUI
import Charts

// MARK: - Accounts Pie Chart (Shared)
struct AccountsPieChart: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    var compact: Bool = false
    
    private var accountData: [(name: String, value: Double, color: Color)] {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .cyan, .yellow, .mint, .indigo, .teal]
        
        var data: [(name: String, value: Double, color: Color)] = []
        
        for (index, account) in viewModel.bankAccounts.enumerated() {
            let details = viewModel.getHoldingDetails(forAccount: account.id)
            // Sum all holdings values for this account
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
    
    private var totalValue: Double {
        accountData.reduce(0) { $0 + $1.value }
    }
    
    var body: some View {
        VStack(spacing: compact ? 8 : 12) {
            if accountData.isEmpty {
                Text(L10n.generalNoData)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Pie Chart
                Chart(accountData, id: \.name) { item in
                    SectorMark(
                        angle: .value("Value", item.value),
                        innerRadius: .ratio(compact ? 0.5 : 0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(4)
                }
                .frame(height: compact ? 120 : 150)
                
                // Legend
                if compact {
                    // Compact legend - vertical list with full names
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(accountData, id: \.name) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 2) {
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
                    }
                } else {
                    // Full legend
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(accountData, id: \.name) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 10, height: 10)
                                Text(item.name)
                                    .font(.caption)
                                Spacer()
                                if !privacyMode {
                                    Text(formatCurrency(item.value, currency: "EUR"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("(\(Int((item.value / totalValue) * 100))%)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                } else {
                                    Text("***")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(compact ? 8 : 12)
    }
}
