import SwiftUI

/// Full-size quadrant chart with period chips and moving averages.
struct QuadrantTrendDetailView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("privacyMode") private var privacyMode = false

    let quadrant: Quadrant

    @State private var history: [(date: Date, value: Double)] = []
    @State private var cashflows: [PortfolioCashflow] = []
    @State private var hasCompleteCashflows = true
    @State private var movingAverageRatios: [MovingAverageWindow: [(date: Date, value: Double)]] = [:]
    @State private var isLoading = true
    @AppStorage(ChartComparisonSelection.storageKey) private var comparisonSelection = ChartComparisonSelection.defaultValue
    /// Market lines replayed with this category's cash flows.
    @State private var marketComparisons: [ChartComparison] = []
    /// Returns of the other categories that are checked in the Compare menu.
    @State private var otherReturns: [Int: [(date: Date, value: Double)]] = [:]

    private var comparisons: [ChartComparison] {
        let others = viewModel.quadrants.filter { $0.id != quadrant.id }.map { other in
            ChartComparison(
                id: ChartComparison.quadrantID(other.id),
                label: other.name,
                color: AppTheme.allocationColor(id: other.id),
                history: otherReturns[other.id] ?? [],
                kind: .precomputedReturn,
                group: .quadrant
            )
        }
        return marketComparisons + others
    }

    private struct OtherReturnsKey: Equatable {
        let ids: [Int]
        let period: ReportPeriod
    }

    private var otherReturnsKey: OtherReturnsKey {
        OtherReturnsKey(
            ids: ChartComparisonSelection.quadrantIDs(comparisonSelection)
                .filter { id in id != quadrant.id && viewModel.quadrants.contains { $0.id == id } },
            period: viewModel.selectedPeriod
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    PeriodChips(selectedPeriod: $viewModel.selectedPeriod)
                        .padding(.horizontal)
                    if history.isEmpty {
                        Group {
                            if isLoading { ProgressView() } else { Text(L10n.generalNoData).foregroundStyle(.secondary) }
                        }
                        .frame(maxWidth: .infinity, minHeight: 250)
                    } else {
                        PortfolioTrendChart(
                            history: history,
                            comparisons: comparisons,
                            performancePercent: viewModel.cachedQuadrantTWR[quadrant.id],
                            seriesLabel: quadrant.name,
                            interactive: true,
                            privacyMode: privacyMode,
                            cashflows: cashflows,
                            hasCompleteCashflows: hasCompleteCashflows,
                            movingAverageRatios: movingAverageRatios,
                            onRequestLongHistory: downloadLongHistory
                        )
                        .frame(minHeight: 320)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(quadrant.name)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.generalDone) { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 520)
        #endif
        .task(id: viewModel.selectedPeriod) { await load() }
        .task(id: otherReturnsKey) { await loadOtherReturns() }
    }

    private func load() async {
        isLoading = true
        let loadedHistory = await viewModel.getQuadrantValueHistory(quadrantId: quadrant.id)
        let transactions = await viewModel.getQuadrantTransactions(quadrantId: quadrant.id)
        let data = await viewModel.cashflowData(transactions: transactions)
        history = loadedHistory
        cashflows = data.cashflows
        hasCompleteCashflows = await viewModel.hasCompletePeriodCashflows(transactions)
        isLoading = false
        // Same rule as the portfolio chart: no market comparison without complete cash flows.
        if hasCompleteCashflows {
            let markets = await viewModel.marketComparisonSeries(base: loadedHistory, baseCashflows: data.cashflows)
            marketComparisons = [
                (ChartComparison.msciWorldID, L10n.chartMsciWorldComparison, AppTheme.msciWorld, markets.msciWorld),
                (ChartComparison.sp500ID, L10n.chartSp500Comparison, AppTheme.sp500, markets.sp500),
                (ChartComparison.goldID, L10n.chartGoldComparison, AppTheme.gold, markets.gold)
            ]
            .filter { !$0.3.isEmpty }
            .map { ChartComparison(id: $0.0, label: $0.1, color: $0.2, history: $0.3) }
        } else {
            marketComparisons = []
        }
        movingAverageRatios = await viewModel.quadrantMovingAverageRatios(
            quadrantId: quadrant.id,
            at: loadedHistory.map(\.date)
        )
    }

    private func loadOtherReturns() async {
        var loaded: [Int: [(date: Date, value: Double)]] = [:]
        for id in otherReturnsKey.ids {
            if Task.isCancelled { return }
            loaded[id] = await viewModel.getQuadrantReturnSeries(quadrantId: id)
        }
        if Task.isCancelled { return }
        otherReturns = loaded
    }

    private func downloadLongHistory() async {
        let instruments = viewModel.instruments.filter { $0.quadrantId == quadrant.id }
        for (index, instrument) in instruments.enumerated() {
            if index > 0 { try? await Task.sleep(nanoseconds: 500_000_000) }
            await viewModel.backfillSingleInstrument(instrument, period: "max", interval: "1wk", silent: true)
        }
        await load()
    }
}
