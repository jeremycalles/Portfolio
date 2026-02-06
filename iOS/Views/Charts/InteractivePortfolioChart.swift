import SwiftUI
import Charts

// MARK: - Interactive Portfolio Chart
struct InteractivePortfolioChart: View {
    let history: [(date: Date, value: Double)]
    let isPositive: Bool
    let privacyMode: Bool
    
    @State private var selectedDate: Date?
    @State private var lastHapticDate: Date?
    
    private var minValue: Double {
        history.map { $0.value }.min() ?? 0
    }
    
    private var maxValue: Double {
        history.map { $0.value }.max() ?? 0
    }
    
    private var chartColor: Color {
        isPositive ? .green : .red
    }
    
    /// Find the closest data point to the selected date
    private func findClosestDataPoint(to date: Date) -> (date: Date, value: Double)? {
        guard !history.isEmpty else { return nil }
        return history.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }
    
    /// Trigger haptic feedback
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    var body: some View {
        if privacyMode {
            // Blurred placeholder when privacy mode is on
            ZStack {
                Chart(history, id: \.date) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(.gray.opacity(0.3))
                }
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)
                .blur(radius: 8)
                
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
            }
        } else {
            ZStack(alignment: .top) {
                Chart(history, id: \.date) { item in
                    // Area fill
                    AreaMark(
                        x: .value("Date", item.date),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [chartColor.opacity(0.3), chartColor.opacity(0.05), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    
                    // Line
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(chartColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }
                // Selection rule mark (vertical line)
                .chartOverlay { proxy in
                    if let selectedDate,
                       let dataPoint = findClosestDataPoint(to: selectedDate) {
                        GeometryReader { geometry in
                            if let xPosition = proxy.position(forX: dataPoint.date) {
                                // Vertical rule line
                                Rectangle()
                                    .fill(chartColor.opacity(0.3))
                                    .frame(width: 1)
                                    .position(x: xPosition, y: geometry.size.height / 2)
                                
                                // Point indicator
                                if let yPosition = proxy.position(forY: dataPoint.value) {
                                    Circle()
                                        .fill(chartColor)
                                        .frame(width: 10, height: 10)
                                        .shadow(color: chartColor.opacity(0.5), radius: 4, x: 0, y: 0)
                                        .position(x: xPosition, y: yPosition)
                                    
                                    // Outer ring
                                    Circle()
                                        .stroke(chartColor.opacity(0.3), lineWidth: 2)
                                        .frame(width: 18, height: 18)
                                        .position(x: xPosition, y: yPosition)
                                }
                            }
                        }
                    }
                }
                .chartXSelection(value: $selectedDate)
                .chartYScale(domain: minValue * 0.98 ... maxValue * 1.02)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundStyle(Color.gray.opacity(0.3))
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundStyle(Color.gray.opacity(0.3))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Tooltip annotation popup
                if let selectedDate,
                   let dataPoint = findClosestDataPoint(to: selectedDate) {
                    ChartTooltipView(date: dataPoint.date, value: dataPoint.value, color: chartColor)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: selectedDate)
                }
            }
            .onChange(of: selectedDate) { oldValue, newValue in
                // Trigger haptic when selection changes to a different data point
                if let newValue,
                   let newPoint = findClosestDataPoint(to: newValue) {
                    if lastHapticDate != newPoint.date {
                        triggerHaptic()
                        lastHapticDate = newPoint.date
                    }
                } else if newValue == nil {
                    lastHapticDate = nil
                }
            }
        }
    }
}
