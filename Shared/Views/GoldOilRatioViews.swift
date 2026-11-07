import SwiftUI
import Charts

/// Indicator card: current Gold/Oil ratio, change over the selected period and a
/// sparkline. Tapping opens the full chart.
struct GoldOilRatioCard: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var data = GoldOilRatioData()
    @State private var hasLoaded = false
    @State private var showingDetail = false

    private struct LoadKey: Equatable {
        let period: ReportPeriod
        let benchmarks: Int
        let lastUpdate: Date?
    }

    private var change: Double? {
        guard let first = data.history.first?.value, let last = data.history.last?.value else { return nil }
        return PortfolioHistoryBuilder.percentChange(from: first, to: last)
    }

    var body: some View {
        Group {
            if data.history.isEmpty {
                // Nothing to show until gold and Brent have been downloaded once.
                if !hasLoaded { ProgressView().frame(maxWidth: .infinity, minHeight: 60) }
            } else {
                container {
                    Button { showingDetail = true } label: { content }
                        .buttonStyle(.plain)
                        .accessibilityHint(L10n.goldOilOpenChart)
                }
            }
        }
        .task(id: LoadKey(period: viewModel.selectedPeriod, benchmarks: viewModel.benchmarkRevision, lastUpdate: viewModel.lastInstrumentUpdateDate)) {
            let loaded = await viewModel.goldOilRatioData()
            if !Task.isCancelled { data = loaded; hasLoaded = true }
        }
        .sheet(isPresented: $showingDetail) {
            GoldOilRatioDetailView().environmentObject(viewModel)
        }
    }

    @ViewBuilder
    private func container<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        #if os(macOS)
        GroupBox { content().padding(4) }
        #else
        content().portfolioCard()
        #endif
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.goldOilTitle).font(.headline)
            Text(L10n.goldOilSubtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(data.history.last.map { String(format: "%.1f", $0.value) } ?? L10n.generalNA)
                    .font(.title2.weight(.semibold)).monospacedDigit()
                if let change {
                    Text(formatPercentChange(change))
                        .font(.caption.weight(.medium)).monospacedDigit()
                        .foregroundStyle(AppTheme.changeColor(change))
                }
            }
            sparkline.frame(height: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var sparkline: some View {
        let values = data.history.map(\.value)
        let lo = values.min() ?? 0
        let hi = values.max() ?? 1
        return Chart {
            ForEach(Array(data.history.enumerated()), id: \.offset) { _, point in
                LineMark(x: .value("Date", point.date), y: .value("Ratio", point.value))
                    .interpolationMethod(.linear)
                    .foregroundStyle(AppTheme.changeColor(change ?? 0))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: lo <= hi && hi - lo > 1e-9 ? lo...hi : (lo - 1)...(lo + 1))
        .accessibilityHidden(true)
    }
}

/// Full chart for the ratio, with period chips and moving averages.
struct GoldOilRatioDetailView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var data = GoldOilRatioData()
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    PeriodChips(selectedPeriod: $viewModel.selectedPeriod)
                        .padding(.horizontal)
                    Text(L10n.goldOilSubtitle)
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal)
                    if data.history.isEmpty {
                        Group {
                            if isLoading { ProgressView() } else { Text(L10n.generalNoData).foregroundStyle(.secondary) }
                        }
                        .frame(maxWidth: .infinity, minHeight: 250)
                    } else {
                        PortfolioTrendChart(
                            history: data.history,
                            unit: "ratio",
                            seriesLabel: L10n.goldOilTitle,
                            interactive: true,
                            isSensitive: false,
                            movingAverageRatios: data.movingAverageRatios,
                            onRequestLongHistory: downloadLongHistory
                        )
                        .frame(minHeight: 320)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(L10n.goldOilTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
        data = await viewModel.goldOilRatioData()
        isLoading = false
    }

    private func downloadLongHistory() async {
        await viewModel.downloadGoldOilLongHistory()
        await load()
    }
}
