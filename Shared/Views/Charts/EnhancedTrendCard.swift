import SwiftUI
import Charts

// MARK: - Enhanced Trend Card
struct EnhancedTrendCard: View {
    let title: String
    let history: [(date: Date, value: Double)]
    let currentValue: Double?
    let privacyMode: Bool
    var performancePercent: Double? = nil
    var unit: String = "EUR"  // "EUR" or "oz" for gold ounces
    
    private var changePercent: Double? {
        if let performancePercent { return performancePercent }
        guard let first = history.first?.value,
              let last = history.last?.value else { return nil }
        return PortfolioHistoryBuilder.percentChange(from: first, to: last)
    }
    
    private var chartColor: Color {
        if let change = changePercent {
            return change >= 0 ? AppTheme.gain : AppTheme.loss
        }
        return AppTheme.portfolio
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
    
    /// Tight y-domain so a sparkline shows movement; an area from zero flattened it.
    private var yDomain: ClosedRange<Double> {
        let values = history.map(\.value)
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        let pad = max((high - low) * 0.1, abs(high) * 0.001, 0.0001)
        return (low - pad)...(high + pad)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(AppTheme.Typography.sectionTitle)
                    .lineLimit(1)
                
                Spacer()
                
                if let change = changePercent {
                    HStack(spacing: 3) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(AppTheme.Typography.caption.weight(.bold))
                        Text(formatPercentChange(change, fractionDigits: 1))
                            .font(AppTheme.Typography.label.weight(.semibold))
                            .monospacedDigit()
                    }
                    .foregroundColor(AppTheme.changeColor(change))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppTheme.changeColor(change).opacity(0.12)))
                    .fixedSize()
                }
            }
            
            // Current value leads; the period's start value is secondary context.
            VStack(alignment: .leading, spacing: 2) {
                if let value = currentValue {
                    Text(privacyMode ? "•••" : formatValue(value))
                        .font(AppTheme.Typography.value)
                        .foregroundStyle(privacyMode ? .secondary : .primary)
                }
                if let startValue = history.first?.value, !privacyMode {
                    Text("\(L10n.summaryFrom) \(formatValue(startValue))")
                        .font(AppTheme.Typography.label)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            
            if history.isEmpty {
                Text(unit == "oz" ? L10n.chartNoGoldPriceData : L10n.generalNoData)
                    .foregroundColor(.secondary)
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(history, id: \.date) { item in
                    AreaMark(
                        x: .value("Date", item.date),
                        yStart: .value("Base", yDomain.lowerBound),
                        yEnd: .value("Value", item.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [chartColor.opacity(0.18), chartColor.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.linear)

                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(chartColor)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.linear)
                }
                .chartYScale(domain: yDomain)
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)
                .frame(height: 56)
                .accessibilityHidden(true)
            }
        }
        .padding(AppTheme.Spacing.large)
        .modifier(GlassEffectFallback(cornerRadius: AppTheme.Radius.card, interactive: false))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Glass effect with fallback for systems before Liquid Glass
struct GlassEffectFallback: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var cornerRadius: CGFloat
    var interactive: Bool

    func body(content: Content) -> some View {
        #if os(iOS) || os(macOS)
        if #available(iOS 26.0, macOS 26.0, *), !reduceTransparency {
            if interactive {
                content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        #else
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        #endif
    }
}

extension View {
    func portfolioGlassSurface(cornerRadius: CGFloat, interactive: Bool = false) -> some View {
        modifier(GlassEffectFallback(cornerRadius: cornerRadius, interactive: interactive))
    }
}

// MARK: - Previews

#Preview("EnhancedTrendCard") {
    let today = Date()
    let history: [(date: Date, value: Double)] = (0..<30).reversed().compactMap { i in
        guard let date = Calendar.current.date(byAdding: .day, value: -i, to: today) else { return nil }
        return (date: date, value: 1370 * (1 + Double(30 - i) / 30.0 * 0.06))
    }
    EnhancedTrendCard(title: "Lyxor MSCI World", history: history, currentValue: 1452, privacyMode: false)
        .frame(width: 350)
        .padding()
}
