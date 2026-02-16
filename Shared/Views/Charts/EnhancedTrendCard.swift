import SwiftUI
import Charts
#if os(macOS)
import AppKit
#endif

// MARK: - Enhanced Trend Card
struct EnhancedTrendCard: View {
    let title: String
    let history: [(date: Date, value: Double)]
    let currentValue: Double?
    let privacyMode: Bool
    var unit: String = "EUR"  // "EUR" or "oz" for gold ounces
    
    private var changePercent: Double? {
        guard let first = history.first?.value,
              let last = history.last?.value,
              first > 0 else { return nil }
        return ((last - first) / first) * 100
    }
    
    private var chartColor: Color {
        if let change = changePercent {
            return change >= 0 ? .green : .red
        }
        return .blue
    }
    
    private func formatValue(_ value: Double) -> String {
        if unit == "oz" {
            if value >= 100 {
                return String(format: "%.1f oz", value)
            } else if value >= 10 {
                return String(format: "%.2f oz", value)
            } else {
                return String(format: "%.3f oz", value)
            }
        } else {
            return formatCurrency(value, currency: "EUR")
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and change badge
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Spacer()
                
                // Change badge
                if let change = changePercent {
                    HStack(spacing: 3) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(String(format: "%.1f%%", abs(change)))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(change >= 0 ? .green : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill((change >= 0 ? Color.green : Color.red).opacity(0.12))
                    )
                }
            }
            
            // Start value (left) and current value (right)
            HStack {
                // Value at starting date of the graph (left)
                if let startValue = history.first?.value {
                    if privacyMode {
                        Text("•••")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    } else {
                        Text(formatValue(startValue))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                }
                Spacer()
                // Current price (right)
                if let value = currentValue {
                    if privacyMode {
                        Text("•••")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    } else {
                        Text(formatValue(value))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                }
            }
            
            // Chart
            if history.isEmpty {
                Text(unit == "oz" ? L10n.chartNoGoldPriceData : L10n.generalNoData)
                    .foregroundColor(.secondary)
                    .frame(height: 80)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(history, id: \.date) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(chartColor)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Date", item.date),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [chartColor.opacity(0.2), chartColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)
                .frame(height: 80)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                #if os(iOS)
                .fill(Color(.systemBackground))
                #else
                .fill(Color(NSColor.windowBackgroundColor))
                #endif
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}
