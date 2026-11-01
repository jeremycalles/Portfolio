import SwiftUI

struct EnhancedPortfolioHeroCard: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dynamicTypeSize) private var typeSize
    let currentValue: Double
    let previousValue: Double
    let privacyMode: Bool
    var selectedPeriod: Binding<ReportPeriod>? = nil
    @State private var goldMode = false

    private var details: [HoldingDetail] { viewModel.cachedHoldingDetailsByAccount.values.flatMap { $0 } }
    private var isPartial: Bool { details.contains { $0.currentValueEUR == nil } }
    private var dates: [String] { details.compactMap(\.priceDate).sorted() }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text(goldMode ? L10n.dashboardPortfolioValueGold : isPartial ? L10n.designKnownValue : L10n.dashboardPortfolioValue)
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button(L10n.designCurrencyEUR) { goldMode = false }
                    Button(L10n.designGoldUnits) { goldMode = true }
                        .disabled(viewModel.cachedGoldTotals == nil || viewModel.demoMode.isDemoModeEnabled)
                } label: {
                    Label(goldMode ? "oz" : "EUR", systemImage: "chevron.down")
                        .font(.subheadline).frame(minHeight: 44)
                }
            }
            Text(value)
                .font(AppTheme.Typography.hero)
                .minimumScaleFactor(0.75)
                .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
            if !goldMode {
                let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) : AnyLayout(HStackLayout(alignment: .top, spacing: 20))
                layout {
                    metric(L10n.designInvestmentReturn, value: viewModel.cachedPeriodTWR.map { formatPercentChange($0) }, change: viewModel.cachedPeriodTWR)
                    metric(L10n.designGain, value: viewModel.cachedPeriodGainEUR.map { formatCurrency($0, currency: "EUR") }, change: viewModel.cachedPeriodGainEUR)
                }
            }
            if let selectedPeriod { PeriodChips(selectedPeriod: selectedPeriod) }
            if let oldest = dates.first {
                Label {
                    Text("\(L10n.designOldestQuote): \(AppDateFormatter.displayDate(oldest))")
                } icon: { Image(systemName: "clock") }
                .font(.caption).foregroundStyle(.secondary)
            }
            if let checked = viewModel.getLastRefreshDate() {
                Text("\(L10n.designLastChecked): \(checked.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(Locale(identifier: LanguageManager.shared.currentLanguage.rawValue))))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 8)
    }

    private var value: String {
        if privacyMode { return L10n.privacyHiddenLong }
        if !details.isEmpty && details.allSatisfy({ $0.currentValueEUR == nil }) { return L10n.generalNA }
        if goldMode && !viewModel.demoMode.isDemoModeEnabled, let gold = viewModel.cachedGoldTotals {
            return "\(gold.current.formatted(.number.precision(.fractionLength(2)))) oz"
        }
        return formatCurrency(currentValue, currency: "EUR")
    }

    private func metric(_ title: String, value: String?, change: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(privacyMode || viewModel.demoMode.isDemoModeEnabled ? L10n.privacyHiddenLong : (value ?? L10n.generalNA))
                .font(AppTheme.Typography.value)
                .foregroundStyle(privacyMode || viewModel.demoMode.isDemoModeEnabled ? Color.secondary : change.map(AppTheme.changeColor) ?? .secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }
}

struct PeriodChips: View {
    @Binding var selectedPeriod: ReportPeriod
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let primary: [ReportPeriod] = [.oneWeek, .oneMonth, .oneYear, .yearToDate]

    var body: some View {
        if typeSize.isAccessibilitySize {
            periodMenu
        } else {
            HStack(spacing: 4) {
                ForEach(primary) { period in
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) { selectedPeriod = period }
                    } label: {
                        Text(period.shortName).font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(selectedPeriod == period ? AppTheme.onSelection : .primary)
                            .background(selectedPeriod == period ? AppTheme.selection : .clear, in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain)
                        .accessibilityLabel(period.displayName)
                        .accessibilityAddTraits(selectedPeriod == period ? .isSelected : [])
                }
                periodMenu
            }
        }
    }

    private var periodMenu: some View {
        Menu {
            Picker(L10n.designPeriod, selection: $selectedPeriod) {
                ForEach(ReportPeriod.allCases) { Text($0.displayName).tag($0) }
            }
        } label: {
            if typeSize.isAccessibilitySize || !primary.contains(selectedPeriod) {
                Label(typeSize.isAccessibilitySize ? selectedPeriod.displayName : selectedPeriod.shortName, systemImage: "chevron.down")
                    .font(.subheadline).frame(minWidth: 44, minHeight: 44)
            } else {
                Image(systemName: "ellipsis").frame(width: 44, height: 44)
                    .accessibilityLabel(L10n.designPeriod)
            }
        }
    }
}
