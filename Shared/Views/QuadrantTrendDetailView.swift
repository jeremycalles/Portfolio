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
                            performancePercent: viewModel.cachedQuadrantTWR[quadrant.id],
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
        movingAverageRatios = await viewModel.quadrantMovingAverageRatios(
            quadrantId: quadrant.id,
            at: loadedHistory.map(\.date)
        )
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
