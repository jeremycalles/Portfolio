import SwiftUI

struct iOSInstrumentsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showingAdd = false
    @State private var search = ""
    @State private var deleting: Instrument?
    private var instruments: [Instrument] {
        viewModel.instruments.filter { search.isEmpty || [$0.displayName, $0.isin, $0.ticker ?? ""].joined(separator: " ").localizedCaseInsensitiveContains(search) }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
    var body: some View {
        List {
            ForEach(instruments) { instrument in
                NavigationLink { iOSInstrumentDetailView(instrument: instrument) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(instrument.displayName).font(.headline)
                        Text(instrument.isin).font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 6)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) { deleting = instrument } label: { Label(L10n.generalDelete, systemImage: "trash") }
                        .disabled(viewModel.demoMode.isDemoModeEnabled)
                }
            }
            if instruments.isEmpty {
                ContentUnavailableView {
                    Label(search.isEmpty ? L10n.instrumentsTitle : L10n.designNoMatches, systemImage: "doc.text.magnifyingglass")
                } description: { Text(L10n.designNoInstruments) } actions: {
                    Button(L10n.designNewInstrument) { showingAdd = true }.disabled(viewModel.demoMode.isDemoModeEnabled)
                }
            }
        }
        .navigationTitle(L10n.navInstruments)
        .searchable(text: $search, prompt: L10n.designInstrumentSearch)
        .toolbar { ToolbarItem(placement: .primaryAction) {
            Button { showingAdd = true } label: { Image(systemName: "plus") }
                .accessibilityLabel(L10n.designNewInstrument).disabled(viewModel.demoMode.isDemoModeEnabled)
        } }
        .sheet(isPresented: $showingAdd) { InstrumentSetupSheet() }
        .confirmationDialog(L10n.designDeleteInstrumentWarning, isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            if let instrument = deleting { Button(L10n.generalDelete, role: .destructive) { Task { await viewModel.deleteInstrument(instrument.isin) } } }
        }
    }
}

// MARK: - iOS Instrument Detail View
struct iOSInstrumentDetailView: View {
    @EnvironmentObject var viewModel: AppViewModel
    private let initialInstrument: Instrument
    init(instrument: Instrument) { self.initialInstrument = instrument }
    private var instrument: Instrument {
        viewModel.instruments.first { $0.isin == initialInstrument.isin } ?? initialInstrument
    }
    @State private var selectedQuadrantId: Int?
    @State private var showingAddPriceSheet = false
    @State private var showingEditPriceSheet = false
    @State private var showingEditInstrumentSheet = false
    @State private var showingBackfillLogs = false
    @State private var priceToEdit: Price?
    @State private var priceToDelete: Price?
    @State private var priceHistory: [Price] = []
    
    var body: some View {
        List {
            Section(L10n.designPositionDetails) {
                LabeledContent(L10n.designIdentifier, value: instrument.isin)
                LabeledContent(L10n.instrumentsName, value: instrument.name ?? "N/A")
                if let ticker = instrument.ticker {
                    LabeledContent(L10n.instrumentsTicker, value: ticker)
                }
                if let currency = instrument.currency {
                    LabeledContent(L10n.instrumentsCurrency, value: currency)
                }
            }
            
            Section {
                Picker(L10n.instrumentsQuadrants, selection: $selectedQuadrantId) {
                    Text(L10n.instrumentsUnassigned).tag(nil as Int?)
                    ForEach(viewModel.quadrants) { quadrant in
                        Text(quadrant.name).tag(quadrant.id as Int?)
                    }
                }
                .disabled(viewModel.demoMode.isDemoModeEnabled)
                .onChange(of: selectedQuadrantId) { _, newValue in
                    if newValue != instrument.quadrantId {
                        Task { await viewModel.assignQuadrant(instrumentIsin: instrument.isin, quadrantId: newValue) }
                    }
                }
            } header: {
                Text(L10n.quadrantsQuadrantAssignment)
            } footer: {
                Text(L10n.quadrantsAssignmentHint)
            }
            
            Section {
                if priceHistory.isEmpty {
                    Text(L10n.chartNoPriceHistory)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(priceHistory, id: \.id) { price in
                        Button {
                            priceToEdit = price
                            showingEditPriceSheet = true
                        } label: {
                            HStack {
                                Text(AppDateFormatter.displayDate(price.date))
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
                        .disabled(viewModel.demoMode.isDemoModeEnabled)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                priceToDelete = price
                            } label: {
                                Label(L10n.generalDelete, systemImage: "trash")
                            }.disabled(viewModel.demoMode.isDemoModeEnabled)
                        }
                    }
                }
            } header: {
                HStack {
                    Text(L10n.navPriceHistory)
                    Spacer()
                    Menu {
                        Button(L10n.actionBackfill1Month) {
                            Task {
                                await viewModel.backfillSingleInstrument(instrument, period: "1mo", interval: "1d")
                                await refreshPriceHistory()
                                showingBackfillLogs = true
                            }
                        }
                        Button(L10n.actionBackfill1Year) {
                            Task {
                                await viewModel.backfillSingleInstrument(instrument, period: "1y", interval: "1mo")
                                await refreshPriceHistory()
                                showingBackfillLogs = true
                            }
                        }
                        Button(L10n.actionBackfill2Years) {
                            Task {
                                await viewModel.backfillSingleInstrument(instrument, period: "2y", interval: "1mo")
                                await refreshPriceHistory()
                                showingBackfillLogs = true
                            }
                        }
                        Button(L10n.actionBackfill5Years) {
                            Task {
                                await viewModel.backfillSingleInstrument(instrument, period: "5y", interval: "1mo")
                                await refreshPriceHistory()
                                showingBackfillLogs = true
                            }
                        }
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.accentColor)
                    }
                    .disabled(viewModel.isLoading || viewModel.demoMode.isDemoModeEnabled)
                    .accessibilityLabel(L10n.designDownloadHistory)
                    
                    Button {
                        showingAddPriceSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                    }.disabled(viewModel.demoMode.isDemoModeEnabled)
                        .accessibilityLabel(L10n.actionAddPrice)
                }
            }
        }
        .confirmationDialog(L10n.generalDelete, isPresented: Binding(get: { priceToDelete != nil }, set: { if !$0 { priceToDelete = nil } }), titleVisibility: .visible) {
            if let price = priceToDelete {
                Button(L10n.generalDelete, role: .destructive) {
                    Task { await viewModel.deletePrice(isin: instrument.isin, date: price.date); await refreshPriceHistory() }
                }
            }
        } message: {
            if let price = priceToDelete { Text(L10n.reportsDeleteConfirmation(AppDateFormatter.displayDate(price.date))) }
        }
        .navigationTitle(instrument.displayName)
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(L10n.generalEdit) {
                    showingEditInstrumentSheet = true
                }.disabled(viewModel.demoMode.isDemoModeEnabled)
            }
        }
        .onAppear {
            selectedQuadrantId = instrument.quadrantId
            Task { await refreshPriceHistory() }
        }
        .sheet(isPresented: $showingEditInstrumentSheet) {
            iOSInstrumentEditSheet(
                instrument: instrument,
                onDismiss: { showingEditInstrumentSheet = false },
                onSave: { updated in
                    viewModel.dismissError()
                    await viewModel.updateInstrument(updated)
                    return viewModel.errorMessage == nil
                }
            )
            .environmentObject(viewModel)
        }
        .sheet(isPresented: $showingAddPriceSheet) {
            PriceEditorSheet(
                instrument: instrument,
                existingPrice: nil,
                onSave: { date, value, currency in
                        let saved = await viewModel.addManualPrice(isin: instrument.isin, date: date, value: value, currency: currency)
                        await refreshPriceHistory()
                        return saved
                    }
            )
        }
        .sheet(isPresented: $showingEditPriceSheet) {
            if let price = priceToEdit {
                PriceEditorSheet(
                    instrument: instrument,
                    existingPrice: price,
                    onSave: { date, value, currency in
                        let saved = await viewModel.addManualPrice(isin: instrument.isin, date: date, value: value, currency: currency, replacingDate: price.date)
                        await refreshPriceHistory()
                        return saved
                    }
                )
            }
        }
        .sheet(isPresented: $showingBackfillLogs) {
            BackfillLogsSheet(logs: viewModel.backfillLogs)
        }
    }
    
    private func refreshPriceHistory() async {
        priceHistory = await viewModel.getPriceHistory(forIsin: instrument.isin)
    }
}

// MARK: - iOS Instrument Edit Sheet
struct iOSInstrumentEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let instrument: Instrument
    let onDismiss: () -> Void
    let onSave: (Instrument) async -> Bool
    @State private var name = ""
    @State private var ticker = ""
    @State private var isSaving = false
    @State private var saveFailed = false

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.designPositionDetails) {
                    LabeledContent(L10n.designIdentifier, value: instrument.isin)
                    TextField(L10n.instrumentsName, text: $name)
                    TextField(L10n.instrumentsTicker, text: $ticker)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    LabeledContent(L10n.instrumentsCurrency, value: instrument.currency ?? L10n.generalNA)
                }
                if saveFailed { Text(L10n.errorSaveFailed).foregroundStyle(.red) }
            }
            .disabled(isSaving)
            .navigationTitle(L10n.instrumentsEditInstrument)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.generalCancel, action: onDismiss).disabled(isSaving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? L10n.designSaving : L10n.generalSave) {
                        isSaving = true
                        Task {
                            let cleanTicker = ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                            let updated = Instrument(isin: instrument.isin, ticker: cleanTicker.isEmpty ? nil : cleanTicker,
                                name: name.trimmingCharacters(in: .whitespacesAndNewlines), currency: instrument.currency, quadrantId: instrument.quadrantId)
                            if await onSave(updated) { dismiss() } else { saveFailed = true }
                            isSaving = false
                        }
                    }.disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .interactiveDismissDisabled(isSaving)
            .onAppear { name = instrument.displayName; ticker = instrument.ticker ?? "" }
        }
    }
}

// MARK: - Previews

#Preview("iOSInstrumentsView") {
    NavigationStack {
        iOSInstrumentsView()
            .environmentObject(AppViewModel.preview)
    }
}
