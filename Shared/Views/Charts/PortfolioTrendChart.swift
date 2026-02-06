import SwiftUI
import Charts

// MARK: - Portfolio Trend Chart (series for S&P 500 color scale)
enum PortfolioChartSeries: String, CaseIterable, Plottable {
    case portfolio
    case sp500
    case gold
    case msciWorld
}

struct PortfolioTrendChart: View {
    let history: [(date: Date, value: Double)]
    var sp500History: [(date: Date, value: Double)]? = nil  // Optional S&P 500 comparison (same amount invested)
    var goldHistory: [(date: Date, value: Double)]? = nil   // Optional Gold comparison
    var msciWorldHistory: [(date: Date, value: Double)]? = nil // Optional MSCI World comparison
    var compact: Bool = false
    var unit: String = "EUR"  // "EUR" or "oz" for gold ounces

    private var valueRange: (min: Double, max: Double) {
        var lo = Double.greatestFiniteMagnitude
        var hi = -Double.greatestFiniteMagnitude
        func scan(_ items: [(date: Date, value: Double)]) {
            for item in items {
                if item.value < lo { lo = item.value }
                if item.value > hi { hi = item.value }
            }
        }
        scan(history)
        if let sp = sp500History { scan(sp) }
        if let gd = goldHistory { scan(gd) }
        if let mw = msciWorldHistory { scan(mw) }
        return history.isEmpty ? (0, 0) : (lo, hi)
    }

    private var minValue: Double { valueRange.min }
    private var maxValue: Double { valueRange.max }

    private var valueChange: Double? {
        guard let first = history.first?.value, let last = history.last?.value, first > 0 else {
            return nil
        }
        return ((last - first) / first) * 100
    }

    private var chartColor: Color {
        if let change = valueChange {
            return change >= 0 ? .green : .red
        }
        return .blue
    }

    private var startDate: Date? {
        history.first?.date
    }

    private var endDate: Date? {
        history.last?.date
    }

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        return f
    }()
    
    private static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()
    
    private var dateFormatter: DateFormatter {
        compact ? Self.shortDateFormatter : Self.mediumDateFormatter
    }

    private func formatValue(_ value: Double) -> String {
        if unit == "oz" {
            // Gold ounces format
            if value >= 100 {
                return String(format: "%.1f oz", value)
            } else if value >= 10 {
                return String(format: "%.2f oz", value)
            } else {
                return String(format: "%.3f oz", value)
            }
        } else {
            // Currency format
            return formatCompactCurrency(value)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            // Legend and % on the same line
            let hasSp500 = sp500History != nil && !(sp500History?.isEmpty ?? true)
            let hasGold = goldHistory != nil && !(goldHistory?.isEmpty ?? true)
            let hasMsci = msciWorldHistory != nil && !(msciWorldHistory?.isEmpty ?? true)
            
            if (valueChange != nil) || hasSp500 || hasGold || hasMsci {
                HStack {
                    if hasSp500 || hasGold || hasMsci {
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Circle().fill(chartColor).frame(width: 6, height: 6)
                                Text(L10n.chartPortfolioLabel).font(.caption2).foregroundColor(.secondary)
                            }
                            if hasSp500 {
                                HStack(spacing: 4) {
                                    Circle().fill(Color.orange).frame(width: 6, height: 6)
                                    Text(L10n.chartSp500Comparison).font(.caption2).foregroundColor(.secondary)
                                }
                            }
                            if hasGold {
                                HStack(spacing: 4) {
                                    Circle().fill(Color.yellow).frame(width: 6, height: 6)
                                    Text(L10n.chartGoldComparison).font(.caption2).foregroundColor(.secondary)
                                }
                            }
                            if hasMsci {
                                HStack(spacing: 4) {
                                    Circle().fill(Color.purple).frame(width: 6, height: 6)
                                    Text(L10n.chartMsciWorldComparison).font(.caption2).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    Spacer()
                    if let change = valueChange {
                        HStack(spacing: 2) {
                            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption2)
                            Text(String(format: "%+.2f%%", change))
                                .font(compact ? .caption2 : .caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(chartColor)
                    }
                }
                .padding(.horizontal, compact ? 8 : 16)
            }

            Chart {
                ForEach(Array(history.enumerated()), id: \.offset) { _, item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(by: .value("Series", PortfolioChartSeries.portfolio))
                    .interpolationMethod(.catmullRom)
                    AreaMark(
                        x: .value("Date", item.date),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [chartColor.opacity(0.3), chartColor.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 0))
                }
                if let sp = sp500History, !sp.isEmpty {
                    ForEach(Array(sp.enumerated()), id: \.offset) { _, item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Value", item.value)
                        )
                        .foregroundStyle(by: .value("Series", PortfolioChartSeries.sp500))
                        .interpolationMethod(.catmullRom)
                    }
                }
                if let gd = goldHistory, !gd.isEmpty {
                    ForEach(Array(gd.enumerated()), id: \.offset) { _, item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Value", item.value)
                        )
                        .foregroundStyle(by: .value("Series", PortfolioChartSeries.gold))
                        .interpolationMethod(.catmullRom)
                    }
                }
                if let mw = msciWorldHistory, !mw.isEmpty {
                    ForEach(Array(mw.enumerated()), id: \.offset) { _, item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Value", item.value)
                        )
                        .foregroundStyle(by: .value("Series", PortfolioChartSeries.msciWorld))
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
            .chartForegroundStyleScale([
                PortfolioChartSeries.portfolio: chartColor,
                PortfolioChartSeries.sp500: Color.orange,
                PortfolioChartSeries.gold: Color.yellow,
                PortfolioChartSeries.msciWorld: Color.purple
            ])
            .chartYScale(domain: minValue * 0.98 ... maxValue * 1.02)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(formatValue(doubleValue))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartLegend(.hidden)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(compact ? 8 : 16)
    }
}
