import SwiftUI
import Charts

// MARK: - Quadrant Report View
struct QuadrantReportView: View {
    @EnvironmentObject var viewModel: AppViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Period Picker
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
                
                // Report Content
                let report = viewModel.getQuadrantReport()
                
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
                    // Quadrant sections
                    ForEach(report) { item in
                        QuadrantSection(item: item)
                    }
                    
                    // Grand Total (EUR)
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.generalGrandTotal.uppercased())
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Divider()
                            
                            let totals = viewModel.getGrandTotalsEUR()
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
    @State private var showingAddSheet = false
    @State private var showingDeleteAlert = false
    @State private var priceToEdit: Price?
    @State private var priceToDelete: Price?
    
    var body: some View {
        HSplitView {
            // Instrument list
            List(viewModel.instruments, selection: $selectedInstrument) { instrument in
                VStack(alignment: .leading) {
                    Text(instrument.displayName)
                        .lineLimit(1)
                    Text(instrument.isin)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .tag(instrument)
            }
            .frame(minWidth: 200, maxWidth: 300)
            .onChange(of: selectedInstrument) { _, newValue in
                refreshPriceHistory()
            }
            
            // Price history
            VStack {
                if let instrument = selectedInstrument {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(instrument.displayName)
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            if let latest = priceHistory.first {
                                VStack(alignment: .trailing) {
                                    Text(formatCurrency(latest.value, currency: instrument.currency ?? "EUR"))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Text(L10n.reportsAsOf(latest.date))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Menu {
                                Button("1 Month (Daily)") {
                                    Task {
                                        await viewModel.backfillSingleInstrument(instrument, period: "1mo", interval: "1d")
                                        refreshPriceHistory()
                                    }
                                }
                                Button("1 Year (Monthly)") {
                                    Task {
                                        await viewModel.backfillSingleInstrument(instrument, period: "1y", interval: "1mo")
                                        refreshPriceHistory()
                                    }
                                }
                                Button("2 Years (Monthly)") {
                                    Task {
                                        await viewModel.backfillSingleInstrument(instrument, period: "2y", interval: "1mo")
                                        refreshPriceHistory()
                                    }
                                }
                                Button("5 Years (Monthly)") {
                                    Task {
                                        await viewModel.backfillSingleInstrument(instrument, period: "5y", interval: "1mo")
                                        refreshPriceHistory()
                                    }
                                }
                            } label: {
                                Image(systemName: "clock.arrow.circlepath")
                            }
                            .disabled(viewModel.isLoading)
                            .help("Backfill historical data for this instrument")
                            
                            Button {
                                showingAddSheet = true
                            } label: {
                                Image(systemName: "plus")
                            }
                            .help(L10n.tooltipAddPrice)
                        }
                        .padding()
                        
                        Divider()
                        
                        if priceHistory.isEmpty {
                            VStack {
                                Spacer()
                                Text(L10n.reportsNoPriceHistoryAvailable)
                                    .foregroundColor(.secondary)
                                Text(L10n.reportsClickToAddPrice)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        } else {
                            Table(priceHistory) {
                                TableColumn("Date", value: \.date)
                                    .width(120)
                                
                                TableColumn("Price") { price in
                                    Text(formatCurrency(price.value, currency: instrument.currency ?? "EUR"))
                                }
                                .width(min: 100, ideal: 150)
                                
                                TableColumn("Currency") { _ in
                                    Text(instrument.currency ?? "—")
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
                        }
                    }
                } else {
                    VStack {
                        Spacer()
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(L10n.holdingsSelectAnInstrument)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .frame(minWidth: 400)
        }
        .navigationTitle(L10n.navPriceHistory)
        .sheet(isPresented: $showingAddSheet) {
            if let instrument = selectedInstrument {
                PriceEditorSheet(
                    instrument: instrument,
                    existingPrice: nil,
                    onSave: { date, value, currency in
                        viewModel.addManualPrice(isin: instrument.isin, date: date, value: value, currency: currency)
                        refreshPriceHistory()
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
                        // Delete old price if date changed, then add new
                        if date != price.date {
                            viewModel.deletePrice(isin: instrument.isin, date: price.date)
                        }
                        viewModel.addManualPrice(isin: instrument.isin, date: date, value: value, currency: currency)
                        refreshPriceHistory()
                    }
                )
            }
        }
        .alert(L10n.generalDelete, isPresented: $showingDeleteAlert) {
            Button(L10n.generalCancel, role: .cancel) { }
            Button(L10n.generalDelete, role: .destructive) {
                if let instrument = selectedInstrument, let price = priceToDelete {
                    viewModel.deletePrice(isin: instrument.isin, date: price.date)
                    refreshPriceHistory()
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
    }
    
    private func refreshPriceHistory() {
        if let instrument = selectedInstrument {
            priceHistory = viewModel.getPriceHistory(forIsin: instrument.isin)
        } else {
            priceHistory = []
        }
    }
}

// MARK: - Price Editor Sheet
struct PriceEditorSheet: View {
    let instrument: Instrument
    let existingPrice: Price?
    let onSave: (String, Double, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date
    @State private var priceValue: String
    @State private var selectedCurrency: String
    
    private let currencies = ["EUR", "USD", "GBP", "CHF", "JPY"]
    
    init(instrument: Instrument, existingPrice: Price?, onSave: @escaping (String, Double, String) -> Void) {
        self.instrument = instrument
        self.existingPrice = existingPrice
        self.onSave = onSave
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let price = existingPrice {
            _selectedDate = State(initialValue: formatter.date(from: price.date) ?? Date())
            _priceValue = State(initialValue: String(format: "%.4f", price.value))
            _selectedCurrency = State(initialValue: price.currency ?? instrument.currency ?? "EUR")
        } else {
            _selectedDate = State(initialValue: Date())
            _priceValue = State(initialValue: "")
            _selectedCurrency = State(initialValue: instrument.currency ?? "EUR")
        }
    }
    
    private var isValid: Bool {
        guard let value = Double(priceValue), value > 0 else { return false }
        return true
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(existingPrice == nil ? L10n.actionAddPrice : L10n.actionEditPrice)
                    .font(.headline)
                Spacer()
                Text(instrument.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            Divider()
            
            // Form
            Form {
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                
                TextField("Price", text: $priceValue)
                    .textFieldStyle(.roundedBorder)
                
                Picker("Currency", selection: $selectedCurrency) {
                    ForEach(currencies, id: \.self) { currency in
                        Text(currency).tag(currency)
                    }
                }
            }
            .padding()
            
            Divider()
            
            // Buttons
            HStack {
                Button(L10n.generalCancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(existingPrice == nil ? L10n.generalAdd : L10n.generalSave) {
                    if let value = Double(priceValue) {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        let dateString = formatter.string(from: selectedDate)
                        onSave(dateString, value, selectedCurrency)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 350, height: 280)
    }
}

// MARK: - Backfill Logs Sheet
struct BackfillLogsSheet: View {
    let logs: [String]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Backfill Logs")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Logs content
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(logs.enumerated()), id: \.offset) { _, log in
                        if log.isEmpty {
                            Spacer().frame(height: 8)
                        } else {
                            Text(log)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(logColor(for: log))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(Color(NSColor.textBackgroundColor))
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 600, height: 400)
    }
    
    private func logColor(for log: String) -> Color {
        if log.contains("✓") || log.contains("complete") {
            return .green
        } else if log.contains("⚠️") || log.contains("Skipped") || log.contains("No data returned") {
            return .orange
        } else if log.contains("Error") || log.contains("error") {
            return .red
        } else if log.starts(with: "  •") {
            return .secondary
        }
        return .primary
    }
}
#endif

// MARK: - Price Graph View
#if os(macOS)
struct PriceGraphView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedInstrument: Instrument?
    @State private var priceHistory: [Price] = []
    @State private var selectedTimeRange: TimeRange = .oneYear
    
    enum TimeRange: String, CaseIterable, Identifiable {
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case yearToDate = "1 January"
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
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let cutoffStr = formatter.string(from: cutoffDate)
        
        return priceHistory.filter { $0.date >= cutoffStr }
    }
    
    var body: some View {
        HSplitView {
            // Instrument list
            List(viewModel.instruments, selection: $selectedInstrument) { instrument in
                VStack(alignment: .leading) {
                    Text(instrument.displayName)
                        .lineLimit(1)
                    Text(instrument.isin)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .tag(instrument)
            }
            .frame(minWidth: 200, maxWidth: 300)
            .onChange(of: selectedInstrument) { _, newValue in
                if let instrument = newValue {
                    priceHistory = viewModel.getPriceHistory(forIsin: instrument.isin)
                } else {
                    priceHistory = []
                }
            }
            
            // Chart view
            VStack {
                if let instrument = selectedInstrument {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(instrument.displayName)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                if let ticker = instrument.ticker, ticker != "N/A" {
                                    Text(ticker)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if let latest = priceHistory.first {
                                VStack(alignment: .trailing, spacing: 4) {
                                    // Use instrument currency for consistent display
                                    Text(formatCurrency(latest.value, currency: instrument.currency ?? "EUR"))
                                        .font(.title)
                                        .fontWeight(.bold)
                                    Text(L10n.reportsAsOf(latest.date))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    // Calculate change from filtered history
                                    if let oldest = filteredPriceHistory.last, oldest.value > 0 {
                                        let change = ((latest.value - oldest.value) / oldest.value) * 100
                                        HStack(spacing: 4) {
                                            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                                .font(.caption)
                                            Text(String(format: "%+.2f%%", change))
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(change >= 0 ? .green : .red)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Time range picker
                        Picker("Time Range", selection: $selectedTimeRange) {
                            ForEach(TimeRange.allCases) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        Divider()
                        
                        if filteredPriceHistory.isEmpty {
                            VStack {
                                Spacer()
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text(L10n.reportsNoPriceDataForPeriod)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        } else {
                            // Chart
                            PriceChartView(prices: filteredPriceHistory)
                                .padding()
                            
                            // Stats
                            HStack(spacing: 32) {
                                StatBox(
                                    title: "Min",
                                    value: filteredPriceHistory.map { $0.value }.min() ?? 0,
                                    currency: filteredPriceHistory.first?.currency ?? "EUR"
                                )
                                StatBox(
                                    title: "Average",
                                    value: filteredPriceHistory.map { $0.value }.reduce(0, +) / Double(filteredPriceHistory.count),
                                    currency: filteredPriceHistory.first?.currency ?? "EUR"
                                )
                                StatBox(
                                    title: "Max",
                                    value: filteredPriceHistory.map { $0.value }.max() ?? 0,
                                    currency: filteredPriceHistory.first?.currency ?? "EUR"
                                )
                                StatBox(
                                    title: "Data Points",
                                    value: Double(filteredPriceHistory.count),
                                    currency: nil
                                )
                            }
                            .padding()
                        }
                        
                        Spacer()
                    }
                } else {
                    VStack {
                        Spacer()
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(L10n.holdingsSelectAnInstrumentGraph)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .frame(minWidth: 500)
        }
        .navigationTitle(L10n.navPriceGraph)
    }
}
#endif

// MARK: - Price Chart View
struct PriceChartView: View {
    let prices: [Price]
    
    private var chartData: [(date: Date, value: Double)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        return prices.reversed().compactMap { price in
            guard let date = formatter.date(from: price.date) else { return nil }
            return (date: date, value: price.value)
        }
    }
    
    var body: some View {
        Chart(chartData, id: \.date) { item in
            LineMark(
                x: .value("Date", item.date),
                y: .value("Price", item.value)
            )
            .foregroundStyle(.blue)
            .interpolationMethod(.catmullRom)
            
            AreaMark(
                x: .value("Date", item.date),
                y: .value("Price", item.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [.blue.opacity(0.3), .blue.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(String(format: "%.2f", doubleValue))
                            .font(.caption)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month().day())
            }
        }
        .frame(minHeight: 300)
    }
}

// MARK: - Stat Box
#if os(macOS)
struct StatBox: View {
    let title: String
    let value: Double
    let currency: String?
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            if let currency = currency {
                Text(formatCurrency(value, currency: currency))
                    .font(.headline)
            } else {
                Text(String(format: "%.0f", value))
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}
#endif
