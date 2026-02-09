import SwiftUI

// MARK: - Instruments View
#if os(macOS)
struct InstrumentsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingAddSheet = false
    @State private var instrumentToEdit: Instrument?
    @State private var newIsin = ""
    @State private var searchText = ""
    @State private var selectedInstrumentId: Instrument.ID?
    
    var filteredInstruments: [Instrument] {
        if searchText.isEmpty {
            return viewModel.instruments
        }
        return viewModel.instruments.filter {
            $0.isin.localizedCaseInsensitiveContains(searchText) ||
            ($0.name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            ($0.ticker?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                TextField("Search instruments...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
                
                Spacer()
                
                Button {
                    showingAddSheet = true
                } label: {
                    Label(L10n.instrumentsAddInstrument, systemImage: "plus")
                }
            }
            .padding()
            
            Divider()
            
            // Table
            Table(filteredInstruments, selection: $selectedInstrumentId) {
                TableColumn("Name") { instrument in
                    VStack(alignment: .leading) {
                        Text(instrument.displayName)
                            .lineLimit(1)
                        if let ticker = instrument.ticker, ticker != "N/A" {
                            Text(ticker)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .width(min: 200, ideal: 300)
                
                TableColumn("ISIN", value: \.isin)
                    .width(min: 120, ideal: 130)
                
                TableColumn("Currency") { instrument in
                    Text(instrument.currency ?? "—")
                }
                .width(70)
                
                TableColumn("Quadrant") { instrument in
                    if let quadrantId = instrument.quadrantId,
                       let quadrant = viewModel.quadrants.first(where: { $0.id == quadrantId }) {
                        Text(quadrant.name)
                            .foregroundColor(.blue)
                    } else {
                        Text(L10n.instrumentsUnassigned)
                            .foregroundColor(.secondary)
                    }
                }
                .width(min: 100, ideal: 150)
                
                TableColumn("Latest Price") { instrument in
                    if let price = DatabaseService.shared.getLatestPrice(forIsin: instrument.isin) {
                        VStack(alignment: .trailing) {
                            // Use instrument currency for consistent display
                            Text(formatCurrency(price.value, currency: instrument.currency ?? "EUR"))
                            Text(price.date)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("—")
                            .foregroundColor(.secondary)
                    }
                }
                .width(min: 100, ideal: 120)
                
                TableColumn("Actions") { instrument in
                    HStack {
                        Button {
                            instrumentToEdit = instrument
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        .help(L10n.instrumentsEditInstrument)
                        
                        Menu {
                            if viewModel.quadrants.isEmpty {
                                Text(L10n.instrumentsNoQuadrantsAvailable)
                            } else {
                                ForEach(viewModel.quadrants) { quadrant in
                                    Button(quadrant.name) {
                                        viewModel.assignQuadrant(instrumentIsin: instrument.isin, quadrantId: quadrant.id)
                                    }
                                }
                                Divider()
                                Button(L10n.instrumentsRemoveFromQuadrant) {
                                    viewModel.assignQuadrant(instrumentIsin: instrument.isin, quadrantId: nil)
                                }
                            }
                        } label: {
                            Image(systemName: "folder")
                        }
                        .menuStyle(.borderlessButton)
                        .help(L10n.instrumentsAssignToQuadrant)
                        
                        Button {
                            viewModel.deleteInstrument(instrument.isin)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                        .help(L10n.instrumentsDeleteInstrument)
                    }
                }
                .width(80)
            }
        }
        .navigationTitle("\(L10n.instrumentsTitle) (\(viewModel.instruments.count))")
        .sheet(isPresented: $showingAddSheet) {
            AddInstrumentSheet(isPresented: $showingAddSheet)
        }
        .sheet(item: $instrumentToEdit) { instrument in
            EditInstrumentSheet(
                instrument: instrument,
                onDismiss: { instrumentToEdit = nil },
                onSave: { updated in
                    viewModel.updateInstrument(updated)
                    instrumentToEdit = nil
                }
            )
            .environmentObject(viewModel)
        }
    }
}

// MARK: - Add Instrument Sheet
struct AddInstrumentSheet: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Binding var isPresented: Bool
    @State private var isin = ""
    @State private var isAdding = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text(L10n.instrumentsAddInstrument)
                .font(.headline)
            
            Text(L10n.instrumentsIsinHint)
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextField("ISIN / Ticker", text: $isin)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            
            HStack {
                Button(L10n.generalCancel) {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button(L10n.generalAdd) {
                    isAdding = true
                    Task {
                        await viewModel.addInstrument(isin: isin.trimmingCharacters(in: .whitespaces))
                        isAdding = false
                        if viewModel.errorMessage == nil {
                            isPresented = false
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isin.trimmingCharacters(in: .whitespaces).isEmpty || isAdding)
            }
            
            if isAdding {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(30)
        .frame(minWidth: 400)
    }
}

// MARK: - Edit Instrument Sheet
struct EditInstrumentSheet: View {
    @EnvironmentObject var viewModel: AppViewModel
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
    
    private let labelWidth: CGFloat = 72
    
    @ViewBuilder
    private func labeledRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: labelWidth, alignment: .leading)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Instrument")
                        .font(.headline)
                    
                    labeledRow("Name") {
                        TextField("Name", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    labeledRow("ISIN") {
                        Text(instrument.isin)
                            .font(.body.monospaced())
                            .foregroundColor(.secondary)
                    }
                    labeledRow("Ticker") {
                        HStack(spacing: 8) {
                            TextField("Ticker", text: $ticker)
                                .textFieldStyle(.roundedBorder)
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
                            .buttonStyle(.borderless)
                            .disabled(isValidatingTicker)
                            .help("Validate ticker")
                            if isValidatingTicker {
                                ProgressView()
                                    .scaleEffect(0.6)
                            }
                        }
                    }
                    if let message = tickerValidationMessage, let valid = tickerIsValid {
                        HStack(spacing: 12) {
                            Spacer().frame(width: labelWidth + 12)
                            Text(message)
                                .font(.caption)
                                .foregroundColor(valid ? .green : .red)
                        }
                    }
                    labeledRow("Currency") {
                        Picker("", selection: $currency) {
                            ForEach(currencies, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: 120)
                    }
                    labeledRow("Quadrant") {
                        Picker("", selection: $quadrantId) {
                            Text(L10n.instrumentsUnassigned).tag(nil as Int?)
                            ForEach(viewModel.quadrants) { q in
                                Text(q.name).tag(q.id as Int?)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(minWidth: 140)
                    }
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    Text("Latest Price")
                        .font(.headline)
                    
                    if hasLatestPrice {
                        labeledRow("Date") {
                            DatePicker("", selection: $latestPriceDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        labeledRow("Value") {
                            TextField("Value", text: $latestPriceText)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 120)
                        }
                    } else {
                        Text("No price")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Divider()
            
            HStack {
                Button(L10n.generalCancel) {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
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
                        if hasLatestPrice, let value = parseDecimal(latestPriceText), value > 0 {
                            let newDateStr = AppDateFormatter.yearMonthDay.string(from: latestPriceDate)
                            if let old = originalLatestPrice, old.date != newDateStr {
                                viewModel.deletePrice(isin: instrument.isin, date: old.date)
                            }
                            viewModel.addManualPrice(isin: instrument.isin, date: newDateStr, value: value, currency: currency)
                        }
                        onSave(updated)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isValidatingTicker)
            }
            .padding()
        }
        .frame(minWidth: 420, minHeight: 400)
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

// MARK: - Quadrants View
struct QuadrantsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingAddSheet = false
    @State private var newQuadrantName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Spacer()
                
                Button {
                    showingAddSheet = true
                } label: {
                    Label(L10n.quadrantsAddQuadrant, systemImage: "plus")
                }
            }
            .padding()
            
            Divider()
            
            List {
                ForEach(viewModel.quadrants) { quadrant in
                    let instrumentCount = viewModel.instruments.filter { $0.quadrantId == quadrant.id }.count
                    
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading) {
                            Text(quadrant.name)
                                .font(.headline)
                            Text(L10n.instrumentsCount(instrumentCount))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            viewModel.deleteQuadrant(id: quadrant.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }
                
                // Unassigned section
                let unassignedCount = viewModel.instruments.filter { $0.quadrantId == nil }.count
                if unassignedCount > 0 {
                    HStack {
                        Image(systemName: "questionmark.folder")
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading) {
                            Text(L10n.instrumentsUnassigned)
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text(L10n.instrumentsCount(unassignedCount))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(L10n.quadrantsCount(viewModel.quadrants.count))
        .sheet(isPresented: $showingAddSheet) {
            VStack(spacing: 20) {
                Text(L10n.quadrantsAddQuadrant)
                    .font(.headline)
                
                TextField("Quadrant Name", text: $newQuadrantName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                
                HStack {
                    Button(L10n.generalCancel) {
                        showingAddSheet = false
                        newQuadrantName = ""
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    Button(L10n.generalAdd) {
                        viewModel.addQuadrant(name: newQuadrantName.trimmingCharacters(in: .whitespaces))
                        showingAddSheet = false
                        newQuadrantName = ""
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newQuadrantName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(30)
        }
    }
}
#endif
