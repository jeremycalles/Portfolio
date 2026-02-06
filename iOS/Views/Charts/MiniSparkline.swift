import SwiftUI
import Charts

// MARK: - Mini Sparkline
struct MiniSparkline: View {
    let data: [(date: Date, value: Double)]
    let isPositive: Bool
    
    private var normalizedData: [Double] {
        var minVal = Double.greatestFiniteMagnitude
        var maxVal = -Double.greatestFiniteMagnitude
        for item in data {
            if item.value < minVal { minVal = item.value }
            if item.value > maxVal { maxVal = item.value }
        }
        guard !data.isEmpty, maxVal > minVal else {
            return data.map { _ in 0.5 }
        }
        let range = maxVal - minVal
        return data.map { ($0.value - minVal) / range }
    }
    
    private var chartColor: Color {
        isPositive ? .green : .red
    }
    
    var body: some View {
        Chart(Array(data.enumerated()), id: \.offset) { index, item in
            LineMark(
                x: .value("Index", index),
                y: .value("Value", item.value)
            )
            .foregroundStyle(chartColor)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)
            
            AreaMark(
                x: .value("Index", index),
                y: .value("Value", item.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [chartColor.opacity(0.3), chartColor.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}
