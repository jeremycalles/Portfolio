import SwiftUI
import Charts

// MARK: - Portfolio Trend Chart (series for S&P 500 color scale)
enum PortfolioChartSeries: String, CaseIterable, Plottable {
    case portfolio
    case investedCapital
    case movingAverage30
    case movingAverage200
    case movingAverage7y
}

private extension MovingAverageWindow {
    var chartSeries: PortfolioChartSeries {
        switch self {
        case .days30: return .movingAverage30
        case .days200: return .movingAverage200
        case .years7: return .movingAverage7y
        }
    }

    var color: Color {
        switch self {
        case .days30: return AppTheme.movingAverageShort
        case .days200: return AppTheme.movingAverageMedium
        case .years7: return AppTheme.movingAverageLong
        }
    }
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
    /// Series that can be drawn next to the main line, chosen from the Compare menu.
    var comparisons: [ChartComparison] = []
    var performancePercent: Double? = nil
    var compact: Bool = false
    var unit: String = "EUR"  // "EUR", "oz" for gold ounces, or "ratio" for a unitless value
    /// Name of the main line; the portfolio unless the chart shows something else.
    var seriesLabel: String? = nil
    var interactive: Bool = false
    var privacyMode: Bool = false
    /// False for data that is not about the user's holdings, so demo mode keeps it visible.
    var isSensitive = true
    var cashflows: [PortfolioCashflow]? = nil
    var startsWithReturn = false
    var hasCompleteCashflows = true
    /// Moving average divided by the underlying series, at the dates of `history`.
    /// Nil hides the moving-average menu; a missing window means not enough history.
    var movingAverageRatios: [MovingAverageWindow: [(date: Date, value: Double)]]? = nil
    /// Downloads a longer price history so long windows become available.
    var onRequestLongHistory: (() async -> Void)? = nil
    @AppStorage("chartMovingAverages") private var movingAverageSelection = ""
    @State private var isDownloadingHistory = false
    @ObservedObject private var demoMode = DemoModeManager.shared
    private var sensitiveHidden: Bool { isSensitive && (privacyMode || demoMode.isDemoModeEnabled) }
    @AppStorage(ChartComparisonSelection.storageKey) private var comparisonSelection = ChartComparisonSelection.defaultValue
    @State private var didSetInitialMode = false
    @State private var showingExplanation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrubbedPoint: (date: Date, value: Double)?
    @State private var scrubbedXPosition: CGFloat?
    @State private var displayMode: PortfolioChartDisplayMode = .value

    private func displayed(_ items: [(date: Date, value: Double)]?) -> [(date: Date, value: Double)] {
        guard let items else { return [] }
        guard displayMode == .percent else { return items }
        if let cashflows { return hasCompleteCashflows ? PortfolioAnalytics.returnSeries(items, cashflows: cashflows) : [] }
        return PortfolioAnalytics.rebasedPercent(items)
    }

    private var displayedInvested: [(date: Date, value: Double)] {
        displayMode == .value ? (investedCapitalHistory ?? []) : []
    }

    private var visibleTransactionEvents: [PortfolioChartEvent] {
        guard let start = history.first?.date, let end = history.last?.date else { return [] }
        return transactionEvents.filter { $0.date >= start && $0.date <= end }
    }

    private var mainSeriesLabel: String { seriesLabel ?? L10n.chartPortfolioLabel }

    private var displayedHistory: [(date: Date, value: Double)] { displayed(history) }

    /// Comparisons drawn right now: chosen, not capped away, and valid in the current mode.
    private var activeComparisons: [ActiveComparison] {
        let chosen = ChartComparisonSelection.ids(comparisonSelection)
        var result: [ActiveComparison] = []
        for id in chosen {
            guard result.count < ChartComparisonSelection.limit,
                  let comparison = comparisons.first(where: { $0.id == id }) else { continue }
            let series: [(date: Date, value: Double)]
            switch comparison.kind {
            case .benchmark: series = displayed(comparison.history)
            case .precomputedReturn: series = displayMode == .percent ? comparison.history : []
            }
            if !series.isEmpty { result.append(ActiveComparison(comparison: comparison, series: series)) }
        }
        return result
    }

    private struct ActiveComparison {
        let comparison: ChartComparison
        let series: [(date: Date, value: Double)]
    }

    private func isComparisonSelected(_ id: String) -> Bool {
        ChartComparisonSelection.ids(comparisonSelection).contains(id)
    }

    private func setComparison(_ comparison: ChartComparison, selected: Bool) {
        if selected {
            comparisonSelection = ChartComparisonSelection.adding(comparison.id, to: comparisonSelection)
            // Averages and comparisons would crowd the same chart.
            movingAverageSelection = ""
        } else {
            comparisonSelection = ChartComparisonSelection.removing(comparison.id, from: comparisonSelection)
        }
        clearScrubbedPoint()
    }

    private var selectedMovingAverages: [MovingAverageWindow] {
        let selected = Set(movingAverageSelection.split(separator: ",").map(String.init))
        return MovingAverageWindow.allCases.filter {
            selected.contains($0.rawValue) && movingAverageRatios?[$0]?.isEmpty == false
        }
    }

    private func isMovingAverageSelected(_ window: MovingAverageWindow) -> Bool {
        movingAverageSelection.split(separator: ",").contains { $0 == window.rawValue }
    }

    private func setMovingAverage(_ window: MovingAverageWindow, selected: Bool) {
        var values = Set(movingAverageSelection.split(separator: ",").map(String.init))
        if selected {
            values.insert(window.rawValue)
            comparisonSelection = ""
        } else {
            values.remove(window.rawValue)
        }
        movingAverageSelection = MovingAverageWindow.allCases.map(\.rawValue).filter(values.contains).joined(separator: ",")
        clearScrubbedPoint()
    }

    private func movingAverageRatio(_ window: MovingAverageWindow) -> [Date: Double] {
        Dictionary((movingAverageRatios?[window] ?? []).map { ($0.date, $0.value) }, uniquingKeysWith: { _, last in last })
    }

    /// The average projected onto the displayed line: value × ratio, or the
    /// return of the averaged index in percent mode.
    private func displayedMovingAverage(_ window: MovingAverageWindow) -> [(date: Date, value: Double)] {
        let ratios = movingAverageRatio(window)
        guard !ratios.isEmpty else { return [] }
        return displayedHistory.compactMap { point in
            guard let ratio = ratios[point.date] else { return nil }
            let value = displayMode == .percent
                ? ((1 + point.value / 100) * ratio - 1) * 100
                : point.value * ratio
            return value.isFinite ? (point.date, value) : nil
        }
    }

    private var portfolioCapitalSpread: [(date: Date, portfolio: Double, capital: Double)] {
        let capital = displayedInvested
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
        scan(displayedInvested)
        for item in activeComparisons { scan(item.series) }
        for window in selectedMovingAverages { scan(displayedMovingAverage(window)) }
        // Nothing scanned leaves lo > hi; an inverted range crashes Swift Charts.
        guard lo <= hi else { return (0, 1) }
        if abs(hi - lo) < 1e-9 { return (lo - 1, hi + 1) }
        return (lo, hi)
    }

    private var minValue: Double { valueRange.min }
    private var maxValue: Double { valueRange.max }

    /// Time-weighted percent for the badge. The line color follows the euro change of the series.
    private var performanceBadge: Double? {
        if cashflows != nil && !hasCompleteCashflows { return nil }
        if let performancePercent { return performancePercent }
        if let cashflows { return PortfolioAnalytics.returnSeries(history, cashflows: cashflows).last?.value }
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
            return formatPercentChange(value, fractionDigits: abs(maxValue - minValue) < 1 ? 2 : 1)
        }
        if unit == "ratio" {
            return String(format: abs(value) >= 100 ? "%.0f" : "%.1f", value)
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
            return formatPercentChange(value)
        }
        if unit == "ratio" {
            return String(format: "%.2f", value)
        }
        if unit == "oz" {
            return String(format: "%.3f oz", value)
        }
        return formatCurrency(value, currency: "EUR")
    }

    private func legendItem(_ title: String, color: Color, isLine: Bool = false) -> some View {
        HStack(spacing: 4) {
            if isLine {
                Capsule().fill(color).frame(width: 10, height: 3)
            } else {
                Circle().fill(color).frame(width: 6, height: 6)
            }
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .fixedSize()
    }

    var body: some View {
        Group {
            if sensitiveHidden { PrivateValuesPlaceholder() }
            else { visibleChart }
        }
        .onAppear {
            if !didSetInitialMode {
                if startsWithReturn, cashflows != nil { displayMode = .percent }
                didSetInitialMode = true
            }
        }
        .onChange(of: displayMode) { _, _ in clearScrubbedPoint() }
        .onChange(of: history.count) { _, _ in clearScrubbedPoint() }
    }

    private var visibleChart: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            if !compact {
                Picker(L10n.dashboardViewMode, selection: $displayMode) {
                    ForEach(PortfolioChartDisplayMode.allCases) { mode in
                        Text(mode == .value ? L10n.chartValueView : (cashflows == nil ? L10n.designValueChange : L10n.designInvestmentReturn)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
            }
            if !compact {
                HStack {
                    Button { showingExplanation = true } label: {
                        Label(cashflows == nil ? L10n.designValueChange : L10n.designReturnAdjusted, systemImage: "info.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    Spacer()
                    if !comparisons.isEmpty {
                        comparisonMenu
                    }
                    if movingAverageRatios != nil {
                        movingAverageMenu
                    }
                }
                .padding(.horizontal, 8)
            }
            if displayMode == .percent && displayedHistory.isEmpty {
                Text(L10n.designReturnUnavailable).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16)
            }
            // Legend and % on the same line
            let activeComparisons = activeComparisons
            let hasComparisons = !activeComparisons.isEmpty
            let hasInvested = !displayedInvested.isEmpty
            let movingAverages = selectedMovingAverages
            let hasMovingAverages = !movingAverages.isEmpty

            if (performanceBadge != nil) || hasInvested || hasComparisons || hasMovingAverages {
                HStack(alignment: .firstTextBaseline) {
                    if hasInvested || hasComparisons || hasMovingAverages {
                        // Wrap whole items onto a new line instead of hyphenating labels.
                        FlowLayout(spacing: 12, lineSpacing: 4) {
                            legendItem(mainSeriesLabel, color: chartColor)
                            if hasInvested {
                                legendItem(L10n.chartInvestedCapital, color: AppTheme.investedCapital, isLine: true)
                            }
                            ForEach(activeComparisons, id: \.comparison.id) { item in
                                legendItem(item.comparison.label, color: item.comparison.color)
                            }
                            ForEach(movingAverages) { window in
                                legendItem(window.label, color: window.color, isLine: true)
                            }
                        }
                    }
                    Spacer(minLength: 8)
                    if let change = performanceBadge {
                        HStack(spacing: 2) {
                            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption2)
                            Text(formatPercentChange(change))
                                .font(compact ? .caption2 : .caption)
                                .fontWeight(.medium)
                                .monospacedDigit()
                        }
                        .foregroundColor(AppTheme.changeColor(change))
                        .fixedSize()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(change >= 0 ? L10n.changeGain : L10n.changeLoss)
                        .accessibilityValue(formatPercent(abs(change)))
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
                let invested = displayedInvested
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
                ForEach(activeComparisons, id: \.comparison.id) { item in
                    ForEach(Array(item.series.enumerated()), id: \.offset) { _, point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value),
                            series: .value("Comparison", item.comparison.id)
                        )
                        .foregroundStyle(item.comparison.color)
                        .interpolationMethod(.linear)
                    }
                }
                ForEach(movingAverages) { window in
                    ForEach(Array(displayedMovingAverage(window).enumerated()), id: \.offset) { _, item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Value", item.value)
                        )
                        .foregroundStyle(by: .value("Series", window.chartSeries))
                        .interpolationMethod(.linear)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                }
                ForEach(visibleTransactionEvents) { event in
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
                PortfolioChartSeries.movingAverage30: AppTheme.movingAverageShort,
                PortfolioChartSeries.movingAverage200: AppTheme.movingAverageMedium,
                PortfolioChartSeries.movingAverage7y: AppTheme.movingAverageLong
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
                AxisMarks(values: .automatic(desiredCount: compact ? 3 : 4)) { value in
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
        }
        .padding(compact ? 8 : 16)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.dashboardPortfolioTrend)
        .accessibilityValue(accessibilitySummary)
        .accessibilityChartDescriptor(self)
        .alert(L10n.designInvestmentReturn, isPresented: $showingExplanation) {
            Button(L10n.generalOk, role: .cancel) { }
        } message: { Text(L10n.designReturnExplanation) }
    }

    private func scrubbedCallout(for point: (date: Date, value: Double)) -> some View {
        VStack(spacing: 3) {
            Text(Self.shortDateFormatter.string(from: point.date))
                .font(.caption2)
                .foregroundStyle(Color.secondary)
            if sensitiveHidden {
                Text("••••••")
                    .font(.caption.weight(.semibold))
            } else {
                calloutLine(mainSeriesLabel, value: point.value, color: chartColor)
                calloutSeriesLine(L10n.chartInvestedCapital, series: displayedInvested, date: point.date, color: AppTheme.investedCapital)
                ForEach(activeComparisons, id: \.comparison.id) { item in
                    calloutSeriesLine(item.comparison.label, series: item.series, date: point.date, color: item.comparison.color)
                }
                ForEach(selectedMovingAverages) { window in
                    calloutMovingAverageLine(window, date: point.date)
                }
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

    /// Average value plus how far the line sits above or below it.
    private func calloutMovingAverageLine(_ window: MovingAverageWindow, date: Date) -> some View {
        Group {
            if let value = nearestValue(in: displayedMovingAverage(window), to: date),
               let ratio = nearestValue(in: movingAverageRatios?[window] ?? [], to: date), ratio > 0 {
                HStack(spacing: AppTheme.Spacing.xSmall) {
                    Capsule().fill(window.color).frame(width: 8, height: 3)
                    Text(window.label).foregroundStyle(.secondary)
                    Spacer(minLength: AppTheme.Spacing.small)
                    Text(formatScrubbedValue(value)).monospacedDigit()
                    Text(formatPercentChange((1 / ratio - 1) * 100))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.changeColor(1 / ratio - 1))
                }
                .font(.caption2)
            }
        }
    }

    private var comparisonMenu: some View {
        let selectedCount = comparisons.filter { isComparisonSelected($0.id) }.count
        return Menu {
            Section(L10n.chartCompareIndices) {
                ForEach(comparisons.filter { $0.group == .index }) { comparison in
                    comparisonToggle(comparison)
                }
            }
            let quadrants = comparisons.filter { $0.group == .quadrant }
            if !quadrants.isEmpty {
                Section(L10n.chartCompareQuadrants) {
                    ForEach(quadrants) { comparison in
                        // A quadrant is a return, not an amount: only offered in return mode.
                        comparisonToggle(comparison).disabled(displayMode != .percent)
                    }
                }
            }
        } label: {
            Label(
                L10n.chartCompareTo,
                systemImage: selectedCount == 0 ? "plus.circle" : "checkmark.circle.fill"
            )
            .font(.caption)
        }
        .fixedSize()
        .frame(minHeight: 44)
        .accessibilityLabel(L10n.chartCompareTo)
    }

    private func comparisonToggle(_ comparison: ChartComparison) -> some View {
        Toggle(isOn: Binding(
            get: { isComparisonSelected(comparison.id) },
            set: { setComparison(comparison, selected: $0) }
        )) {
            Text(comparison.label)
        }
    }

    private var movingAverageMenu: some View {
        Menu {
            ForEach(MovingAverageWindow.allCases) { window in
                let available = movingAverageRatios?[window]?.isEmpty == false
                Toggle(isOn: Binding(
                    get: { available && isMovingAverageSelected(window) },
                    set: { setMovingAverage(window, selected: $0) }
                )) {
                    Text(available ? window.label : "\(window.label) · \(L10n.chartInsufficientHistory)")
                }
                .disabled(!available)
            }
            if let onRequestLongHistory,
               MovingAverageWindow.allCases.contains(where: { movingAverageRatios?[$0]?.isEmpty != false }) {
                Divider()
                Button {
                    Task {
                        isDownloadingHistory = true
                        await onRequestLongHistory()
                        isDownloadingHistory = false
                    }
                } label: {
                    Label(L10n.chartDownloadLongHistory, systemImage: "arrow.down.circle")
                }
                .disabled(isDownloadingHistory)
            }
        } label: {
            if isDownloadingHistory {
                ProgressView().controlSize(.small)
            } else {
                Label(
                    L10n.chartMovingAverages,
                    systemImage: selectedMovingAverages.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill"
                )
                .font(.caption)
            }
        }
        .fixedSize()
        .frame(minHeight: 44)
        .accessibilityLabel(L10n.chartMovingAverages)
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
        let surface = Rectangle().fill(.clear).contentShape(Rectangle())
        #if os(macOS)
        surface
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { updateScrubbedPoint(at: $0.location.x, proxy: proxy, geometry: geometry) }
                .onEnded { _ in clearScrubbedPoint() })
            .onContinuousHover { phase in
                switch phase {
                case .active(let location): updateScrubbedPoint(at: location.x, proxy: proxy, geometry: geometry)
                case .ended: clearScrubbedPoint()
                }
            }
        #else
        // A normal drag continues to scroll the page; holding first explores the chart.
        surface.gesture(
            LongPressGesture(minimumDuration: 0.25)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .onChanged { value in
                    if case .second(true, let drag?) = value {
                        updateScrubbedPoint(at: drag.location.x, proxy: proxy, geometry: geometry)
                    }
                }
                .onEnded { _ in clearScrubbedPoint() }
        )
        #endif
    }

    private func clearScrubbedPoint() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            scrubbedPoint = nil
            scrubbedXPosition = nil
        }
    }

    private var paddedYDomain: ClosedRange<Double> {
        let padding = max(abs(maxValue - minValue) * 0.06, 0.01)
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
        if sensitiveHidden { return L10n.designValuesHidden }
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
            name: mainSeriesLabel,
            isContinuous: true,
            dataPoints: (sensitiveHidden ? [] : displayedHistory).map {
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
