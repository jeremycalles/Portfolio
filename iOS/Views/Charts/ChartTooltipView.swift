import SwiftUI
import Charts

// MARK: - Chart Tooltip View
struct ChartTooltipView: View {
    let date: Date
    let value: Double
    let color: Color
    
    private var dateFormatter: DateFormatter {
        AppDateFormatter.mediumDate
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateFormatter.string(from: date))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(formatCurrency(value, currency: "EUR"))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 8)
    }
}
