import SwiftUI
import Charts

// MARK: - Mini Sparkline
struct MiniSparkline: View {
    let data: [(date: Date, value: Double)]
    let isPositive: Bool
    
    private var normalizedData: [Double] {
        guard let minVal = data.map({ $0.value }).min(),
              let maxVal = data.map({ $0.value }).max(),
              maxVal > minVal else {
            return data.map { _ in 0.5 }
        }
        return data.map { ($0.value - minVal) / (maxVal - minVal) }
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
