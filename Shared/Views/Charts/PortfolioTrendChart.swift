import SwiftUI
import Charts

// MARK: - Portfolio Trend Chart (series for S&P 500 color scale)
enum PortfolioChartSeries: String, CaseIterable, Plottable {
    case portfolio
    case investedCapital
    case sp500
    case gold
    case msciWorld
}

private enum PortfolioChartDisplayMode: String, CaseIterable, Identifiable {
    case value
    case percent
    var id: String { rawValue }
    var title: String { self == .value ? L10n.chartValueView : L10n.chartPercentView }
}

struct PortfolioTrendChart: View {
    let history: [(date: Date, value: Double)]
    var investedCapitalHistory: [(date: Date, value: Double)]? = nil
    var transactionEvents: [PortfolioChartEvent] = []
    var sp500History: [(date: Date, value: Double)]? = nil  // Optional S&P 500 comparison (same amount invested)
    var goldHistory: [(date: Date, value: Double)]? = nil   // Optional Gold comparison
    var msciWorldHistory: [(date: Date, value: Double)]? = nil // Optional MSCI World comparison
    var performancePercent: Double? = nil
    var compact: Bool = false
    var unit: String = "EUR"  // "EUR" or "oz" for gold ounces
    var interactive: Bool = false
    var privacyMode: Bool = false
    @State private var scrubbedPoint: (date: Date, value: Double)?
    @State private var scrubbedXPosition: CGFloat?
    @State private var displayMode: PortfolioChartDisplayMode = .value

    private func displayed(_ items: [(date: Date, value: Double)]?) -> [(date: Date, value: Double)] {
        guard let items else { return [] }
        return displayMode == .value ? items : PortfolioAnalytics.rebasedPercent(items)
    }

    private var displayedHistory: [(date: Date, value: Double)] { displayed(history) }

    private var portfolioCapitalSpread: [(date: Date, portfolio: Double, capital: Double)] {
        let capital = displayed(investedCapitalHistory)
        guard !capital.isEmpty else { return [] }
        return displayedHistory.compactMap { point in
            guard let capitalValue = nearestValue(in: capital, to: point.date) else { return nil }
            return (point.date, point.value, capitalValue)
        }
    }

    private var valueRange: (min: Double, max: Double) {
        var lo = Double.greatestFiniteMagnitude
        var hi = -Double.greatestFiniteMagnitude
        func scan(_ items: [(date: Date, value: Double)]) {
            for item in items {
                if item.value < lo { lo = item.value }
                if item.value > hi { hi = item.value }
            }
        }
        scan(displayedHistory)
        scan(displayed(investedCapitalHistory))
        scan(displayed(sp500History))
        scan(displayed(goldHistory))
        scan(displayed(msciWorldHistory))
        guard lo.isFinite, hi.isFinite else { return (0, 1) }
        if abs(hi - lo) < 1e-9 { return (lo - 1, hi + 1) }
        return (lo, hi)
    }

    private var minValue: Double { valueRange.min }
    private var maxValue: Double { valueRange.max }

    /// Time-weighted percent for the badge. The line color follows the euro change of the series.
    private var performanceBadge: Double? {
        if let performancePercent { return performancePercent }
        return holdingsPercent
    }

    private var holdingsPercent: Double? {
        guard let first = history.first?.value, let last = history.last?.value else { return nil }
        return PortfolioHistoryBuilder.percentChange(from: first, to: last)
    }

    private var chartColor: Color {
        if let change = performanceBadge {
            return change >= 0 ? AppTheme.gain : AppTheme.loss
        }
        return AppTheme.portfolio
    }

    private var calloutBackground: Color {
        #if os(macOS)
        return Color(nsColor: .windowBackgroundColor).opacity(0.96)
        #else
        return Color(.systemBackground).opacity(0.96)
        #endif
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
        if displayMode == .percent {
            return String(format: "%+.1f%%", value)
        }
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

    private func formatScrubbedValue(_ value: Double) -> String {
        if displayMode == .percent {
            return String(format: "%+.2f%%", value)
        }
        if unit == "oz" {
            return String(format: "%.3f oz", value)
        }
        return formatCurrency(value, currency: "EUR")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            if !compact {
                Picker(L10n.dashboardViewMode, selection: $displayMode) {
                    ForEach(PortfolioChartDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
            }
            // Legend and % on the same line
            let hasSp500 = sp500History != nil && !(sp500History?.isEmpty ?? true)
            let hasGold = goldHistory != nil && !(goldHistory?.isEmpty ?? true)
            let hasMsci = msciWorldHistory != nil && !(msciWorldHistory?.isEmpty ?? true)
            let hasInvested = investedCapitalHistory?.isEmpty == false
            
            if (performanceBadge != nil) || hasInvested || hasSp500 || hasGold || hasMsci {
                HStack {
                    if hasInvested || hasSp500 || hasGold || hasMsci {
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Circle().fill(chartColor).frame(width: 6, height: 6)
                                Text(L10n.chartPortfolioLabel).font(.caption2).foregroundColor(.secondary)
                            }
                            if investedCapitalHistory?.isEmpty == false {
                                HStack(spacing: 4) {
                                    Capsule().fill(AppTheme.investedCapital).frame(width: 10, height: 3)
                                    Text(L10n.chartInvestedCapital).font(.caption2).foregroundColor(.secondary)
                                }
                            }
                            if hasSp500 {
                                HStack(spacing: 4) {
                                    Circle().fill(AppTheme.sp500).frame(width: 6, height: 6)
                                    Text(L10n.chartSp500Comparison).font(.caption2).foregroundColor(.secondary)
                                }
                            }
                            if hasGold {
                                HStack(spacing: 4) {
                                    Circle().fill(AppTheme.gold).frame(width: 6, height: 6)
                                    Text(L10n.chartGoldComparison).font(.caption2).foregroundColor(.secondary)
                                }
                            }
                            if hasMsci {
                                HStack(spacing: 4) {
                                    Circle().fill(AppTheme.msciWorld).frame(width: 6, height: 6)
                                    Text(L10n.chartMsciWorldComparison).font(.caption2).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    Spacer()
                    if let change = performanceBadge {
                        HStack(spacing: 2) {
                            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption2)
                            Text(String(format: "%+.2f%%", change))
                                .font(compact ? .caption2 : .caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(change >= 0 ? AppTheme.gain : AppTheme.loss)
                    }
                }
                .padding(.horizontal, compact ? 8 : 16)
            }

            Chart {
                ForEach(Array(displayedHistory.enumerated()), id: \.offset) { _, item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(by: .value("Series", PortfolioChartSeries.portfolio))
                    .interpolationMethod(.linear)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                ForEach(Array(portfolioCapitalSpread.enumerated()), id: \.offset) { _, item in
                    AreaMark(
                        x: .value("Date", item.date),
                        yStart: .value("Capital", item.capital),
                        yEnd: .value("Portfolio", item.portfolio)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [chartColor.opacity(0.3), chartColor.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.linear)
                    .lineStyle(StrokeStyle(lineWidth: 0))
                }
                let invested = displayed(investedCapitalHistory)
                if !invested.isEmpty {
                    ForEach(Array(invested.enumerated()), id: \.offset) { _, item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Value", item.value)
                        )
                        .foregroundStyle(by: .value("Series", PortfolioChartSeries.investedCapital))
                        .interpolationMethod(.stepEnd)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    }
                }
                let sp = displayed(sp500History)
                if !sp.isEmpty {
                    ForEach(Array(sp.enumerated()), id: \.offset) { _, item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Value", item.value)
                        )
                        .foregroundStyle(by: .value("Series", PortfolioChartSeries.sp500))
                        .interpolationMethod(.linear)
                    }
                }
                let gd = displayed(goldHistory)
                if !gd.isEmpty {
                    ForEach(Array(gd.enumerated()), id: \.offset) { _, item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Value", item.value)
                        )
                        .foregroundStyle(by: .value("Series", PortfolioChartSeries.gold))
                        .interpolationMethod(.linear)
                    }
                }
                let mw = displayed(msciWorldHistory)
                if !mw.isEmpty {
                    ForEach(Array(mw.enumerated()), id: \.offset) { _, item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Value", item.value)
                        )
                        .foregroundStyle(by: .value("Series", PortfolioChartSeries.msciWorld))
                        .interpolationMethod(.linear)
                    }
                }
                ForEach(transactionEvents) { event in
                    if let eventY = nearestValue(in: displayedHistory, to: event.date) {
                        PointMark(
                            x: .value("Transaction", event.date),
                            y: .value("Value", eventY)
                        )
                        .symbol(event.kind == .sell ? .triangle : .circle)
                        .symbolSize(28)
                        .foregroundStyle(event.kind == .sell ? AppTheme.loss : AppTheme.gain)
                    }
                }
                if interactive, let point = scrubbedPoint {
                    RuleMark(x: .value("Selected Date", point.date))
                        .foregroundStyle(.secondary.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                    PointMark(
                        x: .value("Selected Date", point.date),
                        y: .value("Selected Value", point.value)
                    )
                    .foregroundStyle(chartColor)
                    .symbolSize(42)
                }
            }
            .chartForegroundStyleScale([
                PortfolioChartSeries.portfolio: chartColor,
                PortfolioChartSeries.investedCapital: AppTheme.investedCapital,
                PortfolioChartSeries.sp500: AppTheme.sp500,
                PortfolioChartSeries.gold: AppTheme.gold,
                PortfolioChartSeries.msciWorld: AppTheme.msciWorld
            ])
            .chartYScale(domain: paddedYDomain)
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
                AxisMarks(values: .automatic(desiredCount: compact ? 3 : 5)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: xAxisFormat)
                }
            }
            .chartLegend(.hidden)
            .chartOverlay { proxy in
                if interactive {
                    GeometryReader { geometry in
                        ZStack(alignment: .topLeading) {
                            chartInteractionSurface(proxy: proxy, geometry: geometry)

                            if let point = scrubbedPoint,
                               let xPosition = scrubbedXPosition,
                               let plotFrameAnchor = proxy.plotFrame {
                                let plotFrame = geometry[plotFrameAnchor]
                                scrubbedCallout(for: point)
                                    .position(
                                        x: min(max(plotFrame.minX + xPosition, 88), geometry.size.width - 88),
                                        y: plotFrame.minY + 34
                                    )
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(compact ? 8 : 16)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.dashboardPortfolioTrend)
        .accessibilityValue(accessibilitySummary)
        .accessibilityChartDescriptor(self)
    }

    private func scrubbedCallout(for point: (date: Date, value: Double)) -> some View {
        VStack(spacing: 3) {
            Text(Self.shortDateFormatter.string(from: point.date))
                .font(.caption2)
                .foregroundStyle(Color.secondary)
            if privacyMode {
                Text("••••••")
                    .font(.caption.weight(.semibold))
            } else {
                calloutLine(L10n.chartPortfolioLabel, value: point.value, color: chartColor)
                calloutSeriesLine(L10n.chartInvestedCapital, series: displayed(investedCapitalHistory), date: point.date, color: AppTheme.investedCapital)
                calloutSeriesLine(L10n.chartSp500Comparison, series: displayed(sp500History), date: point.date, color: AppTheme.sp500)
                calloutSeriesLine(L10n.chartGoldComparison, series: displayed(goldHistory), date: point.date, color: AppTheme.gold)
                calloutSeriesLine(L10n.chartMsciWorldComparison, series: displayed(msciWorldHistory), date: point.date, color: AppTheme.msciWorld)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(calloutBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
    }

    private func calloutSeriesLine(
        _ label: String,
        series: [(date: Date, value: Double)],
        date: Date,
        color: Color
    ) -> some View {
        Group {
            if let value = nearestValue(in: series, to: date) {
                calloutLine(label, value: value, color: color)
            }
        }
    }

    private func calloutLine(_ label: String, value: Double, color: Color) -> some View {
        HStack(spacing: AppTheme.Spacing.xSmall) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: AppTheme.Spacing.small)
            Text(formatScrubbedValue(value)).monospacedDigit()
        }
        .font(.caption2)
    }

    private func updateScrubbedPoint(at xPosition: CGFloat, proxy: ChartProxy, geometry: GeometryProxy) {
        guard !displayedHistory.isEmpty else { return }
        guard let plotFrameAnchor = proxy.plotFrame else { return }
        let plotFrame = geometry[plotFrameAnchor]
        let relativeX = min(max(xPosition - plotFrame.origin.x, 0), plotFrame.width)
        guard let date: Date = proxy.value(atX: relativeX) else { return }
        let nearest = displayedHistory.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
        if let nearest {
            scrubbedPoint = nearest
            scrubbedXPosition = relativeX
        }
    }

    @ViewBuilder
    private func chartInteractionSurface(proxy: ChartProxy, geometry: GeometryProxy) -> some View {
        let surface = Rectangle()
            .fill(.clear)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateScrubbedPoint(at: value.location.x, proxy: proxy, geometry: geometry)
                    }
                    .onEnded { _ in clearScrubbedPoint() }
            )
        #if os(macOS)
        surface.onContinuousHover { phase in
            switch phase {
            case .active(let location):
                updateScrubbedPoint(at: location.x, proxy: proxy, geometry: geometry)
            case .ended:
                clearScrubbedPoint()
            }
        }
        #else
        surface
        #endif
    }

    private func clearScrubbedPoint() {
        withAnimation(.easeOut(duration: 0.18)) {
            scrubbedPoint = nil
            scrubbedXPosition = nil
        }
    }

    private var paddedYDomain: ClosedRange<Double> {
        let padding = max(abs(maxValue - minValue) * 0.06, displayMode == .percent ? 1 : 0.01)
        return (minValue - padding)...(maxValue + padding)
    }

    private var xAxisFormat: Date.FormatStyle {
        guard let first = history.first?.date, let last = history.last?.date else {
            return .dateTime.month(.abbreviated).day()
        }
        let days = last.timeIntervalSince(first) / 86_400
        if days <= 2 { return .dateTime.hour().minute() }
        if days <= 120 { return .dateTime.month(.abbreviated).day() }
        if days <= 730 { return .dateTime.month(.abbreviated).year(.twoDigits) }
        return .dateTime.year()
    }

    private func nearestValue(
        in series: [(date: Date, value: Double)],
        to date: Date
    ) -> Double? {
        series.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }?.value
    }

    private var accessibilitySummary: String {
        guard let first = displayedHistory.first, let last = displayedHistory.last else {
            return L10n.dashboardNoHistoricalData
        }
        return "\(dateFormatter.string(from: first.date)), \(formatScrubbedValue(first.value)); \(dateFormatter.string(from: last.date)), \(formatScrubbedValue(last.value))"
    }
}

extension PortfolioTrendChart: AXChartDescriptorRepresentable {
    func makeChartDescriptor() -> AXChartDescriptor {
        let start = displayedHistory.first?.date.timeIntervalSinceReferenceDate ?? 0
        let end = displayedHistory.last?.date.timeIntervalSinceReferenceDate ?? start + 1
        let xAxis = AXNumericDataAxisDescriptor(
            title: L10n.chartDateAxis,
            range: start...max(start + 1, end),
            gridlinePositions: []
        ) { timestamp in
            dateFormatter.string(from: Date(timeIntervalSinceReferenceDate: timestamp))
        }
        let yAxis = AXNumericDataAxisDescriptor(
            title: displayMode == .percent ? L10n.chartPercentView : L10n.chartValueView,
            range: paddedYDomain,
            gridlinePositions: []
        ) { value in
            formatScrubbedValue(value)
        }
        let series = AXDataSeriesDescriptor(
            name: L10n.chartPortfolioLabel,
            isContinuous: true,
            dataPoints: displayedHistory.map {
                AXDataPoint(x: $0.date.timeIntervalSinceReferenceDate, y: $0.value)
            }
        )
        return AXChartDescriptor(
            title: L10n.dashboardPortfolioTrend,
            summary: accessibilitySummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

// MARK: - Previews

#Preview("PortfolioTrendChart") {
    let today = Date()
    let history: [(date: Date, value: Double)] = (0..<30).reversed().compactMap { i in
        guard let date = Calendar.current.date(byAdding: .day, value: -i, to: today) else { return nil }
        return (date: date, value: 12_500 * (1 + Double(30 - i) / 30.0 * 0.08))
    }
    PortfolioTrendChart(history: history)
        .frame(height: 300)
        .padding()
}
