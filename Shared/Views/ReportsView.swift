import SwiftUI
import Charts

// MARK: - Quadrant Report View
struct QuadrantReportView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var report: [QuadrantReportItem] = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    Text(L10n.reportsComparisonPeriod)
                        .font(.headline)
                    
                    Picker("Period", selection: $viewModel.selectedPeriod) {
                        ForEach(ReportPeriod.allCases) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 400)
                    
                    Spacer()
                    
                    Text(L10n.reportsVs(formattedComparisonDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                if report.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.pie")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(L10n.reportsNoHoldingsToDisplay)
                            .font(.headline)
                        Text(L10n.reportsAddInstrumentsHint)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                } else {
                    ForEach(report) { item in
                        QuadrantSection(item: item)
                    }
                    
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.generalGrandTotal.uppercased())
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Divider()
                            
                            let totals = (current: report.map { $0.totalValueEUR }.reduce(0, +), previous: report.map { $0.totalPreviousValueEUR }.reduce(0, +))
                            HStack {
                                Text("EUR")
                                    .font(.headline)
                                    .frame(width: 50, alignment: .leading)
                                
                                Text(formatCurrency(totals.current, currency: "EUR"))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                if totals.previous > 0 {
                                    let change = ((totals.current - totals.previous) / totals.previous) * 100
                                    ChangeLabel(change: change)
                                        .font(.headline)
                                }
                            }
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.vertical)
        }
        .navigationTitle(L10n.reportsQuadrantReport)
        .task(id: viewModel.selectedPeriod) {
            report = await viewModel.getQuadrantReport()
        }
    }
    
    var formattedComparisonDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: viewModel.selectedPeriod.comparisonDate)
    }
}

// MARK: - Quadrant Section
struct QuadrantSection: View {
    let item: QuadrantReportItem
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    if let quadrant = item.quadrant {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.orange)
                        Text(quadrant.name.uppercased())
                            .font(.headline)
                    } else {
                        Image(systemName: "questionmark.folder")
                            .foregroundColor(.secondary)
                        Text(L10n.instrumentsUnassigned.uppercased())
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(L10n.instrumentsCount(item.holdings.count))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Holdings table header
                HStack {
                    Text(L10n.holdingsInstrument)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(L10n.holdingsQty)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                    
                    Text(L10n.holdingsValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 120, alignment: .trailing)
                    
                    Text(L10n.holdingsChange)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.vertical, 4)
                
                // Holdings rows
                ForEach(item.holdings) { holding in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(holding.instrumentName)
                                .lineLimit(1)
                            if let ticker = holding.ticker, ticker != "N/A" {
                                Text(ticker)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(formatQuantity(holding.quantity))
                            .frame(width: 80, alignment: .trailing)
                        
                        if let value = holding.currentValueEUR {
                            Text(formatCurrency(value, currency: "EUR"))
                                .frame(width: 120, alignment: .trailing)
                        } else {
                            Text("—")
                                .foregroundColor(.secondary)
                                .frame(width: 120, alignment: .trailing)
                        }
                        
                        if let change = holding.changePercentEUR {
                            ChangeLabel(change: change)
                                .frame(width: 80, alignment: .trailing)
                        } else {
                            Text(L10n.generalNa)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 2)
                }
                
                Divider()
                
                // Subtotal (EUR)
                HStack {
                    Text(L10n.generalSubtotal.uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(formatCurrency(item.totalValueEUR, currency: "EUR"))
                        .fontWeight(.semibold)
                        .frame(width: 120, alignment: .trailing)
                    
                    if let change = item.changePercentEUR {
                        ChangeLabel(change: change)
                            .frame(width: 80, alignment: .trailing)
                    } else {
                        Text("")
                            .frame(width: 80, alignment: .trailing)
                    }
                }
            }
            .padding()
        }
        .padding(.horizontal)
    }
}

// MARK: - Price History View
#if os(macOS)
struct PriceHistoryView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedInstrument: Instrument?
    @State private var priceHistory: [Price] = []
    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var showingDeleteAlert = false
    @State private var priceToEdit: Price?
    @State private var priceToDelete: Price?

    private var filteredInstruments: [Instrument] {
        filteredPriceInstruments(viewModel.instruments, searchText: searchText)
    }
    
    var body: some View {
        HSplitView {
            PriceInstrumentSidebar(
                title: L10n.navPriceHistory,
                instruments: filteredInstruments,
                selectedInstrument: $selectedInstrument,
                searchText: $searchText
            )
            .onChange(of: selectedInstrument) { _, _ in
                Task { await refreshPriceHistory() }
            }
            
            // Price history
            VStack(spacing: 0) {
                if let instrument = selectedInstrument {
                    VStack(alignment: .leading, spacing: 16) {
                        PriceScreenHeader(
                            instrument: instrument,
                            latestPrice: priceHistory.first,
                            pointCount: priceHistory.count,
                            currency: instrument.currency ?? "EUR",
                            actions: {
                                HistoricalBackfillMenu(
                                    isLoading: viewModel.isLoading,
                                    onSelect: { period, interval in
                                        Task {
                                            await viewModel.backfillSingleInstrument(instrument, period: period, interval: interval)
                                            await refreshPriceHistory()
                                        }
                                    }
                                )
                                
                                Button {
                                    showingAddSheet = true
                                } label: {
                                    Label(L10n.generalAdd, systemImage: "plus")
                                }
                                .buttonStyle(.borderedProminent)
                                .help(L10n.tooltipAddPrice)
                            }
                        )
                        
                        if priceHistory.isEmpty {
                            PriceEmptyState(
                                systemImage: "calendar.badge.exclamationmark",
                                title: L10n.reportsNoPriceHistoryAvailable,
                                subtitle: L10n.reportsClickToAddPrice
                            )
                        } else {
                            VStack(spacing: 0) {
                                HStack(spacing: 12) {
                                    PriceMetricCard(
                                        title: "Latest",
                                        value: formatCurrency(priceHistory.first?.value ?? 0, currency: instrument.currency ?? "EUR"),
                                        subtitle: priceHistory.first.map { L10n.reportsAsOf($0.date) }
                                    )
                                    PriceMetricCard(
                                        title: "Oldest",
                                        value: formatCurrency(priceHistory.last?.value ?? 0, currency: instrument.currency ?? "EUR"),
                                        subtitle: priceHistory.last?.date
                                    )
                                    PriceMetricCard(
                                        title: "Entries",
                                        value: "\(priceHistory.count)",
                                        subtitle: "Historical prices"
                                    )
                                }
                                .padding([.horizontal, .top], 16)
                                
                                Table(priceHistory) {
                                    TableColumn("Date", value: \.date)
                                        .width(120)
                                    
                                    TableColumn("Price") { price in
                                        Text(formatCurrency(price.value, currency: instrument.currency ?? "EUR"))
                                            .fontWeight(.medium)
                                    }
                                    .width(min: 100, ideal: 150)
                                    
                                    TableColumn("Currency") { price in
                                        Text(price.currency ?? instrument.currency ?? "—")
                                            .foregroundColor(.secondary)
                                    }
                                    .width(80)
                                    
                                    TableColumn("Actions") { price in
                                        HStack(spacing: 8) {
                                            Button {
                                                priceToEdit = price
                                            } label: {
                                                Image(systemName: "pencil")
                                                    .foregroundColor(.blue)
                                            }
                                            .buttonStyle(.plain)
                                            .help(L10n.tooltipEdit)
                                            
                                            Button {
                                                priceToDelete = price
                                                showingDeleteAlert = true
                                            } label: {
                                                Image(systemName: "trash")
                                                    .foregroundColor(.red)
                                            }
                                            .buttonStyle(.plain)
                                            .help(L10n.tooltipDelete)
                                        }
                                    }
                                    .width(80)
                                }
                                .padding(16)
                            }
                            .modifier(PricePanelStyle())
                        }
                    }
                    .padding(24)
                } else {
                    PriceEmptyState(
                        systemImage: "chart.line.uptrend.xyaxis",
                        title: L10n.holdingsSelectAnInstrument,
                        subtitle: L10n.navPriceHistory
                    )
                }
            }
            .frame(minWidth: 400)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationTitle(L10n.navPriceHistory)
        .sheet(isPresented: $showingAddSheet) {
            if let instrument = selectedInstrument {
                PriceEditorSheet(
                    instrument: instrument,
                    existingPrice: nil,
                    onSave: { date, value, currency in
                        Task {
                            await viewModel.addManualPrice(isin: instrument.isin, date: date, value: value, currency: currency)
                            await refreshPriceHistory()
                        }
                    }
                )
            }
        }
        .sheet(item: $priceToEdit) { price in
            if let instrument = selectedInstrument {
                PriceEditorSheet(
                    instrument: instrument,
                    existingPrice: price,
                    onSave: { date, value, currency in
                        Task {
                            if date != price.date {
                                await viewModel.deletePrice(isin: instrument.isin, date: price.date)
                            }
                            await viewModel.addManualPrice(isin: instrument.isin, date: date, value: value, currency: currency)
                            await refreshPriceHistory()
                        }
                    }
                )
            }
        }
        .alert(L10n.generalDelete, isPresented: $showingDeleteAlert) {
            Button(L10n.generalCancel, role: .cancel) { }
            Button(L10n.generalDelete, role: .destructive) {
                if let instrument = selectedInstrument, let price = priceToDelete {
                    Task {
                        await viewModel.deletePrice(isin: instrument.isin, date: price.date)
                        await refreshPriceHistory()
                    }
                }
            }
        } message: {
            if let price = priceToDelete {
                Text(L10n.reportsDeleteConfirmation(price.date))
            }
        }
        .sheet(isPresented: $viewModel.showBackfillLogs) {
            BackfillLogsSheet(logs: viewModel.backfillLogs)
        }
        .task(id: selectedInstrument?.isin) {
            await refreshPriceHistory()
        }
    }
    
    private func refreshPriceHistory() async {
        if let instrument = selectedInstrument {
            priceHistory = await viewModel.getPriceHistory(forIsin: instrument.isin)
        } else {
            priceHistory = []
        }
    }
}

#endif

// MARK: - Price Graph View
#if os(macOS)
struct PriceGraphView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedInstrument: Instrument?
    @State private var priceHistory: [Price] = []
    @State private var searchText = ""
    @State private var selectedTimeRange: TimeRange = .oneYear
    
    enum TimeRange: String, CaseIterable, Identifiable {
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case yearToDate = "YTD"
        case oneYear = "1Y"
        case twoYears = "2Y"
        case all = "All"
        
        var id: String { rawValue }
        
        var cutoffDate: Date? {
            let today = Date()
            let calendar = Calendar.current
            
            switch self {
            case .oneMonth: return calendar.date(byAdding: .day, value: -30, to: today)
            case .threeMonths: return calendar.date(byAdding: .day, value: -90, to: today)
            case .sixMonths: return calendar.date(byAdding: .day, value: -180, to: today)
            case .yearToDate: return calendar.date(from: DateComponents(year: calendar.component(.year, from: today), month: 1, day: 1))
            case .oneYear: return calendar.date(byAdding: .year, value: -1, to: today)
            case .twoYears: return calendar.date(byAdding: .year, value: -2, to: today)
            case .all: return nil
            }
        }
    }
    
    var filteredPriceHistory: [Price] {
        guard let cutoffDate = selectedTimeRange.cutoffDate else {
            return priceHistory
        }
        
        let cutoffStr = AppDateFormatter.yearMonthDay.string(from: cutoffDate)
        
        return priceHistory.filter { $0.date >= cutoffStr }
    }

    private var filteredInstruments: [Instrument] {
        filteredPriceInstruments(viewModel.instruments, searchText: searchText)
    }

    private var filteredValues: [Double] {
        filteredPriceHistory.map(\.value)
    }

    private var minPrice: Double? {
        filteredValues.min()
    }

    private var averagePrice: Double? {
        guard !filteredValues.isEmpty else { return nil }
        return filteredValues.reduce(0, +) / Double(filteredValues.count)
    }

    private var maxPrice: Double? {
        filteredValues.max()
    }
    
    var body: some View {
        HSplitView {
            PriceInstrumentSidebar(
                title: L10n.navPriceGraph,
                instruments: filteredInstruments,
                selectedInstrument: $selectedInstrument,
                searchText: $searchText
            )
            .onChange(of: selectedInstrument) { _, newValue in
                Task {
                    if let instrument = newValue {
                        priceHistory = await viewModel.getPriceHistory(forIsin: instrument.isin)
                    } else {
                        priceHistory = []
                    }
                }
            }
            
            // Chart view
            VStack(spacing: 0) {
                if let instrument = selectedInstrument {
                    VStack(alignment: .leading, spacing: 16) {
                        PriceScreenHeader(
                            instrument: instrument,
                            latestPrice: priceHistory.first,
                            pointCount: filteredPriceHistory.count,
                            currency: instrument.currency ?? "EUR",
                            changePercent: priceChangePercent
                        ) {
                            Button {
                                Task {
                                    priceHistory = await viewModel.getPriceHistory(forIsin: instrument.isin)
                                }
                            } label: {
                                Label(L10n.actionUpdatePrices, systemImage: "arrow.clockwise")
                            }
                            .disabled(viewModel.isLoading)
                            .help(L10n.tooltipUpdateAllPrices)
                        }

                        HStack {
                            Picker("Time Range", selection: $selectedTimeRange) {
                                ForEach(TimeRange.allCases) { range in
                                    Text(range.rawValue).tag(range)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(maxWidth: 520)

                            Spacer()

                            if let first = filteredPriceHistory.last,
                               let last = filteredPriceHistory.first {
                                Text("\(first.date) - \(last.date)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if filteredPriceHistory.isEmpty {
                            PriceEmptyState(
                                systemImage: "chart.line.uptrend.xyaxis",
                                title: L10n.reportsNoPriceDataForPeriod,
                                subtitle: selectedTimeRange.rawValue
                            )
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                PriceChartView(prices: filteredPriceHistory, currency: instrument.currency ?? filteredPriceHistory.first?.currency ?? "EUR")
                                    .frame(minHeight: 380)

                                HStack(spacing: 12) {
                                    PriceMetricCard(
                                        title: "Min",
                                        value: formatCurrency(minPrice ?? 0, currency: instrument.currency ?? "EUR"),
                                        subtitle: "Lowest close"
                                    )
                                    PriceMetricCard(
                                        title: "Average",
                                        value: formatCurrency(averagePrice ?? 0, currency: instrument.currency ?? "EUR"),
                                        subtitle: "Mean close"
                                    )
                                    PriceMetricCard(
                                        title: "Max",
                                        value: formatCurrency(maxPrice ?? 0, currency: instrument.currency ?? "EUR"),
                                        subtitle: "Highest close"
                                    )
                                    PriceMetricCard(
                                        title: "Data Points",
                                        value: "\(filteredPriceHistory.count)",
                                        subtitle: selectedTimeRange.rawValue
                                    )
                                }
                            }
                            .padding(16)
                            .modifier(PricePanelStyle())
                        }
                    }
                    .padding(24)
                } else {
                    PriceEmptyState(
                        systemImage: "chart.xyaxis.line",
                        title: L10n.holdingsSelectAnInstrumentGraph,
                        subtitle: L10n.navPriceGraph
                    )
                }
            }
            .frame(minWidth: 500)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationTitle(L10n.navPriceGraph)
    }

    private var priceChangePercent: Double? {
        guard let latest = filteredPriceHistory.first,
              let oldest = filteredPriceHistory.last,
              oldest.value > 0 else { return nil }
        return ((latest.value - oldest.value) / oldest.value) * 100
    }
}
#endif

// MARK: - Price Chart View
struct PriceChartView: View {
    let prices: [Price]
    let currency: String
    
    private var chartData: [(date: Date, value: Double)] {
        return prices.reversed().compactMap { price in
            guard let date = AppDateFormatter.yearMonthDay.date(from: price.date) else { return nil }
            return (date: date, value: price.value)
        }
    }

    private var values: [Double] {
        chartData.map(\.value)
    }

    private var chartColor: Color {
        guard let first = chartData.first?.value,
              let last = chartData.last?.value else { return .blue }
        return last >= first ? .green : .red
    }

    private var yDomain: ClosedRange<Double> {
        guard let minValue = values.min(), let maxValue = values.max() else { return 0 ... 1 }
        let padding = Swift.max((maxValue - minValue) * 0.12, maxValue * 0.01)
        return (minValue - padding) ... (maxValue + padding)
    }
    
    var body: some View {
        Chart {
            ForEach(chartData, id: \.date) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Price", item.value)
                )
                .foregroundStyle(chartColor)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", item.date),
                    y: .value("Price", item.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [chartColor.opacity(0.24), chartColor.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            if let latest = chartData.last {
                PointMark(
                    x: .value("Date", latest.date),
                    y: .value("Price", latest.value)
                )
                .foregroundStyle(chartColor)
                .symbolSize(70)
            }
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                    .foregroundStyle(Color.secondary.opacity(0.18))
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(formatCompactCurrency(doubleValue))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                    .foregroundStyle(Color.secondary.opacity(0.12))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.secondary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityLabel("Price chart in \(currency)")
    }
}

// MARK: - Price Screen Components
#if os(macOS)
private func filteredPriceInstruments(_ instruments: [Instrument], searchText: String) -> [Instrument] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return instruments }
    return instruments.filter {
        $0.displayName.localizedCaseInsensitiveContains(query) ||
        $0.isin.localizedCaseInsensitiveContains(query) ||
        ($0.ticker?.localizedCaseInsensitiveContains(query) ?? false)
    }
}

private struct PriceInstrumentSidebar: View {
    let title: String
    let instruments: [Instrument]
    @Binding var selectedInstrument: Instrument?
    @Binding var searchText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Text("\(instruments.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }

                TextField("Search instruments...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(16)

            Divider()

            if instruments.isEmpty {
                PriceEmptyState(
                    systemImage: "magnifyingglass",
                    title: "No instruments",
                    subtitle: searchText
                )
            } else {
                List(instruments, selection: $selectedInstrument) { instrument in
                    PriceInstrumentRow(instrument: instrument)
                        .tag(instrument)
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 240, idealWidth: 300, maxWidth: 340)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct PriceInstrumentRow: View {
    let instrument: Instrument

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.blue)
                .frame(width: 28, height: 28)
                .background(Color.blue.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(instrument.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(instrument.ticker?.isEmpty == false ? instrument.ticker ?? instrument.isin : instrument.isin)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PriceScreenHeader<Actions: View>: View {
    let instrument: Instrument
    let latestPrice: Price?
    let pointCount: Int
    let currency: String
    var changePercent: Double?
    let actions: Actions

    init(
        instrument: Instrument,
        latestPrice: Price?,
        pointCount: Int,
        currency: String,
        changePercent: Double? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.instrument = instrument
        self.latestPrice = latestPrice
        self.pointCount = pointCount
        self.currency = currency
        self.changePercent = changePercent
        self.actions = actions()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(instrument.displayName)
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(instrument.isin)
                    if let ticker = instrument.ticker, ticker != "N/A" {
                        Text(ticker)
                    }
                    Text("\(pointCount) points")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer(minLength: 16)

            if let latestPrice {
                VStack(alignment: .trailing, spacing: 6) {
                    Text(formatCurrency(latestPrice.value, currency: latestPrice.currency ?? currency))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .lineLimit(1)
                    Text(L10n.reportsAsOf(latestPrice.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let changePercent {
                        PriceChangeBadge(change: changePercent)
                    }
                }
            }

            HStack(spacing: 8) {
                actions
            }
        }
        .padding(18)
        .modifier(PricePanelStyle())
    }
}

private struct HistoricalBackfillMenu: View {
    let isLoading: Bool
    let onSelect: (String, String) -> Void

    var body: some View {
        Menu {
            Button("1 Month (Daily)") { onSelect("1mo", "1d") }
            Button("1 Year (Monthly)") { onSelect("1y", "1mo") }
            Button("2 Years (Monthly)") { onSelect("2y", "1mo") }
            Button("5 Years (Monthly)") { onSelect("5y", "1mo") }
        } label: {
            Label("Backfill", systemImage: "clock.arrow.circlepath")
        }
        .disabled(isLoading)
        .help("Backfill historical data for this instrument")
    }
}

private struct PriceMetricCard: View {
    let title: String
    let value: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct PriceChangeBadge: View {
    let change: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2.weight(.bold))
            Text(String(format: "%+.2f%%", change))
                .font(.caption.weight(.semibold))
        }
        .foregroundColor(change >= 0 ? .green : .red)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((change >= 0 ? Color.green : Color.red).opacity(0.12))
        .clipShape(Capsule())
    }
}

private struct PriceEmptyState: View {
    let systemImage: String
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .medium))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

private struct PricePanelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
            )
    }
}
#endif

// MARK: - Previews

#Preview("QuadrantReportView") {
    NavigationStack {
        QuadrantReportView()
            .environmentObject(AppViewModel.preview)
    }
}

#Preview("QuadrantSection") {
    let holdings = [
        HoldingDetail(accountId: 1, isin: "FR0010315770", instrumentName: "Lyxor MSCI World", instrumentCurrency: "EUR", ticker: "EWLD.PA", quantity: 50, currentPrice: 27.40, previousPrice: 25.80, priceDate: "2026-03-22", currentValueEUR: 1370, previousValueEUR: 1290),
        HoldingDetail(accountId: 1, isin: "LU1681043599", instrumentName: "Amundi Nasdaq-100", instrumentCurrency: "EUR", ticker: "PANX.PA", quantity: 30, currentPrice: 85.10, previousPrice: 78.50, priceDate: "2026-03-22", currentValueEUR: 2553, previousValueEUR: 2355),
    ]
    QuadrantSection(item: QuadrantReportItem(quadrant: Quadrant(id: 1, name: "Growth"), holdings: holdings))
}
