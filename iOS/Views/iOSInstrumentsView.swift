import SwiftUI

// MARK: - iOS Instruments View
struct iOSInstrumentsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingAddSheet = false
    @State private var newIsin = ""
    
    var body: some View {
        List {
            ForEach(viewModel.instruments) { instrument in
                NavigationLink {
                    iOSInstrumentDetailView(instrument: instrument)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(instrument.displayName)
                            .font(.headline)
                        HStack {
                            Text(instrument.isin)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            if let ticker = instrument.ticker, ticker != "N/A" {
                                Text(ticker)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    viewModel.deleteInstrument(viewModel.instruments[index].isin)
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                Form {
                    Section("Add Instrument") {
                        TextField("ISIN", text: $newIsin)
                            .textInputAutocapitalization(.characters)
                    }
                }
                .navigationTitle(L10n.instrumentsAddInstrument)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingAddSheet = false
                            newIsin = ""
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            let isinToAdd = newIsin.trimmingCharacters(in: .whitespaces)
                            showingAddSheet = false
                            newIsin = ""
                            if !isinToAdd.isEmpty {
                                Task {
                                    await viewModel.addInstrument(isin: isinToAdd)
                                }
                            }
                        }
                        .disabled(newIsin.isEmpty)
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView(viewModel.statusMessage)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
        }
    }
}

// MARK: - iOS Instrument Detail View
struct iOSInstrumentDetailView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let instrument: Instrument
    @State private var selectedQuadrantId: Int?
    @State private var showingAddPriceSheet = false
    @State private var showingEditPriceSheet = false
    @State private var showingEditInstrumentSheet = false
    @State private var showingBackfillLogs = false
    @State private var priceToEdit: Price?
    @State private var priceHistory: [Price] = []
    
    var body: some View {
        List {
            Section("Details") {
                LabeledContent("ISIN", value: instrument.isin)
                LabeledContent("Name", value: instrument.name ?? "N/A")
                if let ticker = instrument.ticker {
                    LabeledContent("Ticker", value: ticker)
                }
                if let currency = instrument.currency {
                    LabeledContent("Currency", value: currency)
                }
            }
            
            Section {
                Picker("Quadrant", selection: $selectedQuadrantId) {
                    Text("Unassigned").tag(nil as Int?)
                    ForEach(viewModel.quadrants) { quadrant in
                        Text(quadrant.name).tag(quadrant.id as Int?)
                    }
                }
                .onChange(of: selectedQuadrantId) { _, newValue in
                    if newValue != instrument.quadrantId {
                        viewModel.assignQuadrant(instrumentIsin: instrument.isin, quadrantId: newValue)
                    }
                }
            } header: {
                Text("Quadrant Assignment")
            } footer: {
                Text("Quadrants help organize your portfolio into categories for reporting")
            }
            
            Section {
                if priceHistory.isEmpty {
                    Text("No price history")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(priceHistory, id: \.id) { price in
                        Button {
                            priceToEdit = price
                            showingEditPriceSheet = true
                        } label: {
                            HStack {
                                Text(price.date)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(formatCurrency(price.value, currency: instrument.currency ?? "EUR"))
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.deletePrice(isin: instrument.isin, date: price.date)
                                refreshPriceHistory()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Price History")
                    Spacer()
                    Menu {
                        Button("1 Month (Daily)") {
                            Task {
                                await viewModel.backfillSingleInstrument(instrument, period: "1mo", interval: "1d")
                                refreshPriceHistory()
                                showingBackfillLogs = true
                            }
                        }
                        Button("1 Year (Monthly)") {
                            Task {
                                await viewModel.backfillSingleInstrument(instrument, period: "1y", interval: "1mo")
                                refreshPriceHistory()
                                showingBackfillLogs = true
                            }
                        }
                        Button("2 Years (Monthly)") {
                            Task {
                                await viewModel.backfillSingleInstrument(instrument, period: "2y", interval: "1mo")
                                refreshPriceHistory()
                                showingBackfillLogs = true
                            }
                        }
                        Button("5 Years (Monthly)") {
                            Task {
                                await viewModel.backfillSingleInstrument(instrument, period: "5y", interval: "1mo")
                                refreshPriceHistory()
                                showingBackfillLogs = true
                            }
                        }
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.accentColor)
                    }
                    .disabled(viewModel.isLoading)
                    
                    Button {
                        showingAddPriceSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .navigationTitle(instrument.displayName)
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(L10n.generalEdit) {
                    showingEditInstrumentSheet = true
                }
            }
        }
        .onAppear {
            selectedQuadrantId = instrument.quadrantId
            refreshPriceHistory()
        }
        .sheet(isPresented: $showingEditInstrumentSheet) {
            iOSInstrumentEditSheet(
                instrument: instrument,
                onDismiss: { showingEditInstrumentSheet = false },
                onSave: { updated in
                    viewModel.updateInstrument(updated)
                    showingEditInstrumentSheet = false
                }
            )
            .environmentObject(viewModel)
        }
        .sheet(isPresented: $showingAddPriceSheet) {
            iOSPriceEditorSheet(
                instrument: instrument,
                existingPrice: nil,
                onSave: { date, value, currency in
                    viewModel.addManualPrice(isin: instrument.isin, date: date, value: value, currency: currency)
                    refreshPriceHistory()
                }
            )
        }
        .sheet(isPresented: $showingEditPriceSheet) {
            if let price = priceToEdit {
                iOSPriceEditorSheet(
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
        .sheet(isPresented: $showingBackfillLogs) {
            iOSBackfillLogsSheet(logs: viewModel.backfillLogs)
        }
    }
    
    private func refreshPriceHistory() {
        priceHistory = viewModel.getPriceHistory(forIsin: instrument.isin)
    }
}

// MARK: - iOS Backfill Logs Sheet
struct iOSBackfillLogsSheet: View {
    let logs: [String]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(logs.enumerated()), id: \.offset) { _, log in
                        if log.isEmpty {
                            Spacer().frame(height: 12)
                        } else {
                            Text(log)
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundColor(logColor(for: log))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("Backfill Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
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

// MARK: - iOS Instrument Edit Sheet
struct iOSInstrumentEditSheet: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let instrument: Instrument
    let onDismiss: () -> Void
    let onSave: (Instrument) -> Void
    
    @State private var name: String = ""
    @State private var ticker: String = ""
    @State private var currency: String = "EUR"
    @State private var quadrantId: Int? = nil
    @State private var latestPriceDate: Date = Date()
    @State private var latestPriceText: String = ""
    @State private var hasLatestPrice: Bool = false
    @State private var isValidatingTicker: Bool = false
    @State private var tickerValidationMessage: String? = nil
    @State private var tickerIsValid: Bool? = nil
    
    private var originalLatestPrice: Price? { DatabaseService.shared.getLatestPrice(forIsin: instrument.isin) }
    private let currencies = ["EUR", "USD", "GBP", "CHF", "JPY"]
    
    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = .current
        return f
    }()
    
    private func parseNumber(_ text: String) -> Double? {
        if let number = Self.numberFormatter.number(from: text) { return number.doubleValue }
        return Double(text.replacingOccurrences(of: ",", with: "."))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Instrument") {
                    TextField("Name", text: $name)
                    LabeledContent("ISIN", value: instrument.isin)
                    HStack {
                        TextField("Ticker", text: $ticker)
                            .keyboardType(.asciiCapable)
                            .onChange(of: ticker) { _, _ in
                                tickerValidationMessage = nil
                                tickerIsValid = nil
                            }
                        Button {
                            tickerValidationMessage = nil
                            tickerIsValid = nil
                            isValidatingTicker = true
                            Task {
                                let (isValid, message) = await viewModel.validateTicker(isin: instrument.isin, ticker: ticker.isEmpty ? nil : ticker)
                                tickerIsValid = isValid
                                tickerValidationMessage = message
                                isValidatingTicker = false
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(isValidatingTicker)
                        if isValidatingTicker {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .listRowSeparator(tickerValidationMessage != nil ? .hidden : .automatic)
                    if let message = tickerValidationMessage, let valid = tickerIsValid {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(valid ? .green : .red)
                    }
                    Picker("Currency", selection: $currency) {
                        ForEach(currencies, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Quadrant", selection: $quadrantId) {
                        Text(L10n.instrumentsUnassigned).tag(nil as Int?)
                        ForEach(viewModel.quadrants) { q in
                            Text(q.name).tag(q.id as Int?)
                        }
                    }
                }
                
                Section("Latest Price") {
                    if hasLatestPrice {
                        DatePicker("Date", selection: $latestPriceDate, displayedComponents: .date)
                        TextField("Value", text: $latestPriceText)
                            .keyboardType(.decimalPad)
                    } else {
                        Text("No price")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(L10n.instrumentsEditInstrument)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.generalCancel) {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.generalSave) {
                        Task {
                            isValidatingTicker = true
                            tickerValidationMessage = nil
                            tickerIsValid = nil
                            let (isValid, message) = await viewModel.validateTicker(isin: instrument.isin, ticker: ticker.isEmpty ? nil : ticker)
                            tickerIsValid = isValid
                            tickerValidationMessage = message
                            isValidatingTicker = false
                            guard isValid else { return }
                            let updated = Instrument(
                                isin: instrument.isin,
                                ticker: ticker.isEmpty ? nil : ticker,
                                name: name.isEmpty ? nil : name,
                                currency: currency,
                                quadrantId: quadrantId
                            )
                            if hasLatestPrice, let value = parseNumber(latestPriceText), value > 0 {
                                let newDateStr = AppDateFormatter.yearMonthDay.string(from: latestPriceDate)
                                if let old = originalLatestPrice, old.date != newDateStr {
                                    viewModel.deletePrice(isin: instrument.isin, date: old.date)
                                }
                                viewModel.addManualPrice(isin: instrument.isin, date: newDateStr, value: value, currency: currency)
                            }
                            onSave(updated)
                        }
                    }
                    .disabled(isValidatingTicker)
                }
            }
            .onAppear {
                name = instrument.name ?? ""
                ticker = instrument.ticker ?? ""
                currency = instrument.currency ?? "EUR"
                quadrantId = instrument.quadrantId
                if let price = originalLatestPrice {
                    hasLatestPrice = true
                    latestPriceDate = AppDateFormatter.yearMonthDay.date(from: price.date) ?? Date()
                    latestPriceText = String(format: "%.4f", price.value)
                }
            }
        }
    }
}

// MARK: - iOS Price Editor Sheet
struct iOSPriceEditorSheet: View {
    let instrument: Instrument
    let existingPrice: Price?
    let onSave: (String, Double, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date
    @State private var priceText: String
    @State private var selectedCurrency: String
    
    private let currencies = ["EUR", "USD", "GBP", "CHF", "JPY"]
    
    // Locale-aware number formatter (static to avoid re-creation)
    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = .current
        return f
    }()
    
    private func parseNumber(_ text: String) -> Double? {
        // First try with current locale (handles comma as decimal separator)
        if let number = Self.numberFormatter.number(from: text) {
            return number.doubleValue
        }
        // Fallback: try replacing comma with period
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
    
    init(instrument: Instrument, existingPrice: Price?, onSave: @escaping (String, Double, String) -> Void) {
        self.instrument = instrument
        self.existingPrice = existingPrice
        self.onSave = onSave
        
        if let price = existingPrice {
            _selectedDate = State(initialValue: AppDateFormatter.yearMonthDay.date(from: price.date) ?? Date())
            _priceText = State(initialValue: String(format: "%.4f", price.value))
            _selectedCurrency = State(initialValue: price.currency ?? instrument.currency ?? "EUR")
        } else {
            _selectedDate = State(initialValue: Date())
            _priceText = State(initialValue: "")
            _selectedCurrency = State(initialValue: instrument.currency ?? "EUR")
        }
    }
    
    private var isValid: Bool {
        guard let value = parseNumber(priceText), value > 0 else { return false }
        return true
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Price Details") {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    
                    TextField("Price", text: $priceText)
                        .keyboardType(.decimalPad)
                    
                    Picker("Currency", selection: $selectedCurrency) {
                        ForEach(currencies, id: \.self) { currency in
                            Text(currency).tag(currency)
                        }
                    }
                }
                
                Section {
                    HStack {
                        Text("Instrument")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(instrument.displayName)
                            .lineLimit(1)
                    }
                }
            }
            .navigationTitle(existingPrice == nil ? "Add Price" : "Edit Price")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingPrice == nil ? "Add" : "Save") {
                        if let value = parseNumber(priceText) {
                            let dateString = AppDateFormatter.yearMonthDay.string(from: selectedDate)
                            onSave(dateString, value, selectedCurrency)
                            dismiss()
                        }
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}
