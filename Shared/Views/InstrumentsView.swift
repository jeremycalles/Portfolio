import SwiftUI

// MARK: - Instruments View
#if os(macOS)
struct InstrumentsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingAddSheet = false
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
