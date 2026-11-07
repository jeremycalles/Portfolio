import SwiftUI

/// The main performance chart with its Compare menu: indices from the dashboard
/// cache, quadrants computed on demand, only for the ones that are checked.
struct PortfolioPerformanceChart: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @AppStorage(ChartComparisonSelection.storageKey) private var comparisonSelection = ChartComparisonSelection.defaultValue

    var privacyMode = false
    var startsWithReturn = false

    @State private var quadrantReturns: [Int: [(date: Date, value: Double)]] = [:]

    private struct LoadKey: Equatable {
        let quadrantIDs: [Int]
        let period: ReportPeriod
        let lastDate: Date?
        let count: Int
    }

    private var loadKey: LoadKey {
        let history = viewModel.cachedPortfolioHistory
        return LoadKey(
            quadrantIDs: ChartComparisonSelection.quadrantIDs(comparisonSelection)
                .filter { id in viewModel.quadrants.contains { $0.id == id } },
            period: viewModel.selectedPeriod,
            lastDate: history.last?.date,
            count: history.count
        )
    }

    private var comparisons: [ChartComparison] {
        var items: [ChartComparison] = []
        let indices: [(id: String, label: String, color: Color, history: [(date: Date, value: Double)])] = [
            (ChartComparison.msciWorldID, L10n.chartMsciWorldComparison, AppTheme.msciWorld, viewModel.cachedMSCIWorldHistory),
            (ChartComparison.sp500ID, L10n.chartSp500Comparison, AppTheme.sp500, viewModel.cachedSP500History),
            (ChartComparison.goldID, L10n.chartGoldComparison, AppTheme.gold, viewModel.cachedGoldHistory)
        ]
        for index in indices where !index.history.isEmpty {
            items.append(ChartComparison(id: index.id, label: index.label, color: index.color, history: index.history))
        }
        for quadrant in viewModel.quadrants {
            items.append(ChartComparison(
                id: ChartComparison.quadrantID(quadrant.id),
                label: quadrant.name,
                color: AppTheme.allocationColor(id: quadrant.id),
                history: quadrantReturns[quadrant.id] ?? [],
                kind: .precomputedReturn,
                group: .quadrant
            ))
        }
        return items
    }

    var body: some View {
        PortfolioTrendChart(
            history: viewModel.cachedPortfolioHistory,
            investedCapitalHistory: viewModel.cachedInvestedCapitalHistory,
            transactionEvents: viewModel.cachedTransactionEvents,
            comparisons: comparisons,
            performancePercent: viewModel.cachedPeriodTWR,
            interactive: true,
            privacyMode: privacyMode,
            cashflows: viewModel.cachedCashflows,
            startsWithReturn: startsWithReturn,
            hasCompleteCashflows: viewModel.cachedHasCompleteCashflows
        )
        .task(id: loadKey) { await loadQuadrantReturns() }
    }

    private func loadQuadrantReturns() async {
        var loaded: [Int: [(date: Date, value: Double)]] = [:]
        for id in loadKey.quadrantIDs {
            if Task.isCancelled { return }
            loaded[id] = await viewModel.getQuadrantReturnSeries(quadrantId: id)
        }
        if Task.isCancelled { return }
        quadrantReturns = loaded
    }
}
