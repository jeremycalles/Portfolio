import SwiftUI

// MARK: - Enhanced Portfolio Hero Card
struct EnhancedPortfolioHeroCard: View {
    @EnvironmentObject var viewModel: AppViewModel
    let currentValue: Double
    let previousValue: Double
    let privacyMode: Bool
    /// When set, the period chips render inside the card.
    var selectedPeriod: Binding<ReportPeriod>? = nil
    @State private var showGoldMode: Bool = false
    
    private static let relativeDateTimeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        f.dateTimeStyle = .named
        return f
    }()
    
    private var change: Double {
        viewModel.cachedPeriodGainEUR ?? (currentValue - previousValue)
    }
    
    private var changePercent: Double {
        if let twr = viewModel.cachedPeriodTWR { return twr }
        guard previousValue > 0 else { return 0 }
        return (change / previousValue) * 100
    }

    /// The euro amount follows the holdings change; the percent keeps its own sign.
    private var euroIsPositive: Bool {
        change >= 0
    }

    
    private var goldTotals: (current: Double, previous: Double)? {
        viewModel.cachedGoldTotals
    }
    
    private var goldHistory: [(date: Date, value: Double)] {
        viewModel.cachedGoldOzHistory
    }
    
    private var goldChange: Double? {
        guard let first = goldHistory.first?.value, let last = goldHistory.last?.value else { return nil }
        return last - first
    }
    
    private var goldChangePercent: Double? {
        guard let first = goldHistory.first?.value, let last = goldHistory.last?.value else { return nil }
        return PortfolioHistoryBuilder.percentChange(from: first, to: last)
    }
    
    private var isGoldPositive: Bool {
        (goldChange ?? 0) >= 0
    }
    
    /// Capped at now: a timestamp a moment ahead read "in 0 s".
    private var lastRefreshDate: Date? {
        (viewModel.getLastRefreshDate() ?? viewModel.lastInstrumentUpdateDate).map { min($0, Date()) }
    }

    private var isStale: Bool {
        guard let date = lastRefreshDate else { return true }
        return Date().timeIntervalSince(date) > 24 * 60 * 60
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            if currentValue == 0 {
                emptyState
            } else {
                headerRow
                valueRow
            }
            if let selectedPeriod {
                Divider()
                    .padding(.top, AppTheme.Spacing.xSmall)
                PeriodChips(selectedPeriod: selectedPeriod)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.top, 14)
        .padding(.bottom, selectedPeriod == nil ? 14 : AppTheme.Spacing.small)
        .modifier(GlassEffectFallback(cornerRadius: AppTheme.Radius.hero, interactive: false))
        .padding(.horizontal)
    }

    /// "Portfolio value" on the left, freshness on the right; orange once older than a day.
    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(showGoldMode ? L10n.dashboardPortfolioValueGold : L10n.dashboardPortfolioValue)
            Spacer(minLength: AppTheme.Spacing.small)
            if let date = lastRefreshDate {
                Label {
                    Text(Self.relativeDateTimeFormatter.localizedString(for: date, relativeTo: Date()))
                } icon: {
                    if isStale { Image(systemName: "exclamationmark.triangle.fill") }
                }
                .labelStyle(.titleAndIcon)
                .foregroundStyle(isStale ? Color.orange : Color.secondary)
                .accessibilityLabel("\(L10n.summaryLastUpdate) \(Self.relativeDateTimeFormatter.localizedString(for: date, relativeTo: Date()))")
            }
        }
        .font(AppTheme.Typography.label)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    /// Total on the left, change on the right (percent first, amount below), using
    /// the width the old stacked layout left empty.
    private var valueRow: some View {
        HStack(alignment: .lastTextBaseline, spacing: AppTheme.Spacing.medium) {
            valueText
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .layoutPriority(1)
                .contentTransition(.numericText())
                // Long-press keeps the euro / gold-ounce switch without a hidden tap target.
                .onLongPressGesture {
                    HapticService.impact(.medium)
                    withAnimation(.easeInOut(duration: 0.2)) { showGoldMode.toggle() }
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(L10n.dashboardHeroGoldHint)
                .accessibilityAction { showGoldMode.toggle() }
            Spacer(minLength: 0)
            if !privacyMode {
                changeBlock
            }
        }
    }

    @ViewBuilder
    private var valueText: some View {
        if privacyMode {
            Text("••••••")
                .font(AppTheme.Typography.hero)
        } else if showGoldMode, let gold = goldTotals {
            (Text(gold.current.formatted(.number.precision(.fractionLength(2))))
                .font(AppTheme.Typography.hero)
             + Text(" oz")
                .font(.title3.weight(.semibold))
                .foregroundColor(AppTheme.gold))
        } else {
            Text(Self.amountWithSmallCents(formatCurrency(currentValue, currency: "EUR")))
        }
    }

    /// Keeps the cents but sets them smaller, so the total stays readable at a glance.
    private static func amountWithSmallCents(_ formatted: String) -> AttributedString {
        var attributed = AttributedString(formatted)
        attributed.font = AppTheme.Typography.hero
        let separator = Locale.current.decimalSeparator ?? "."
        if let sepRange = formatted.range(of: separator, options: .backwards) {
            let tail = formatted[sepRange.lowerBound...]
            let digits = tail.dropFirst(separator.count).prefix { $0.isNumber }
            let lower = formatted.distance(from: formatted.startIndex, to: sepRange.lowerBound)
            let length = separator.count + digits.count
            let start = attributed.index(attributed.startIndex, offsetByCharacters: lower)
            let end = attributed.index(start, offsetByCharacters: length)
            attributed[start..<end].font = Font.system(.title2, design: .rounded).weight(.semibold).monospacedDigit()
        }
        return attributed
    }

    @ViewBuilder
    private var changeBlock: some View {
        if showGoldMode, goldTotals != nil, let goldChg = goldChange, let goldChgPct = goldChangePercent, goldHistory.first?.value ?? 0 > 0 {
            changeStack(
                percent: goldChgPct,
                amount: "\(goldChg >= 0 ? "+" : "")\(goldChg.formatted(.number.precision(.fractionLength(2)))) oz",
                amountPositive: isGoldPositive
            )
        } else if !showGoldMode, previousValue > 0 {
            changeStack(
                percent: changePercent,
                amount: "\(euroIsPositive ? "+" : "")\(formatCurrency(change, currency: "EUR"))",
                amountPositive: euroIsPositive
            )
        }
    }

    /// Percent leads (the figure people compare across periods); amount follows smaller.
    /// The amount keeps its own sign color: TWR and euro change can disagree.
    private func changeStack(percent: Double, amount: String, amountPositive: Bool) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: percent >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(AppTheme.Typography.label.weight(.bold))
                Text(formatPercentChange(percent))
                    .font(AppTheme.Typography.rowValue)
            }
            .foregroundStyle(AppTheme.changeColor(percent))
            Text(amount)
                .font(AppTheme.Typography.label.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(amountPositive ? AppTheme.gain : AppTheme.loss)
        }
        .lineLimit(1)
        .fixedSize()
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundColor(.secondary.opacity(0.5))
            Text(L10n.dashboardNoHoldings)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Period Chips
/// Compact period picker. Lives inside the hero card because it drives the change
/// figure, best/worst and the performance chart below.
struct PeriodChips: View {
    @Binding var selectedPeriod: ReportPeriod
    @Namespace private var animation

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xSmall) {
            ForEach(ReportPeriod.allCases.filter { $0 != .oneDay }) { period in
                let isSelected = selectedPeriod == period
                Button {
                    HapticService.impact(.light)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        selectedPeriod = period
                    }
                } label: {
                    Text(period.shortName)
                        .font(AppTheme.Typography.control)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .foregroundStyle(isSelected ? AppTheme.onSelection : .primary)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(AppTheme.selection)
                                    .matchedGeometryEffect(id: "period", in: animation)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(period.displayName)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

// MARK: - Previews

#Preview("EnhancedPortfolioHeroCard") {
    EnhancedPortfolioHeroCard(currentValue: 222_337.35, previousValue: 217_629.60, privacyMode: false, selectedPeriod: .constant(.oneWeek))
        .environmentObject(AppViewModel.preview)
        .frame(width: 400)
        .padding()
}
