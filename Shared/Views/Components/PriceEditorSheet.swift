import SwiftUI

// MARK: - Shared Price Editor Sheet
struct PriceEditorSheet: View {
    let instrument: Instrument
    let existingPrice: Price?
    let onSave: (String, Double, String) async -> Bool
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date
    @State private var priceText: String
    @State private var selectedCurrency: String
    @State private var isSaving = false
    @State private var saveFailed = false
    
    private let currencies = ["EUR", "USD", "GBP", "CHF", "JPY"]
    
    init(instrument: Instrument, existingPrice: Price?, onSave: @escaping (String, Double, String) async -> Bool) {
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
        guard let value = parseDecimal(priceText), value.isFinite, value >= 0 else { return false }
        return true
    }
    
    var body: some View {
        #if os(iOS)
        NavigationStack {
            formContent
                .navigationTitle(existingPrice == nil ? L10n.actionAddPrice : L10n.actionEditPrice)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.generalCancel) {
                            dismiss()
                        }.disabled(isSaving)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(existingPrice == nil ? L10n.generalAdd : L10n.generalSave) {
                            Task { await savePrice() }
                        }
                        .disabled(!isValid || isSaving)
                    }
                }
        }
        #else
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
            formContent
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
                    Task { await savePrice() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid || isSaving)
            }
            .padding()
        }
        .frame(minWidth: 350, minHeight: 280)
        #endif
    }
    
    private var formContent: some View {
        Form {
            if saveFailed { Text(L10n.errorSaveFailed).foregroundStyle(.red) }
            Section(L10n.instrumentsPriceDetails) {
                DatePicker(L10n.reportsDate, selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                
                TextField(L10n.instrumentsCurrentPrice, text: $priceText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #else
                    .textFieldStyle(.roundedBorder)
                    #endif
                
                Picker(L10n.instrumentsCurrency, selection: $selectedCurrency) {
                    ForEach(currencies, id: \.self) { currency in
                        Text(currency).tag(currency)
                    }
                }
            }
            
            #if os(iOS)
            Section {
                HStack {
                    Text(L10n.holdingsInstrument)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(instrument.displayName)
                        .lineLimit(1)
                }
            }
            #endif
        }
        .disabled(isSaving)
        .interactiveDismissDisabled(isSaving)
    }
    
    private func savePrice() async {
        if let value = parseDecimal(priceText) {
            let dateString = AppDateFormatter.yearMonthDay.string(from: selectedDate)
            guard !isSaving else { return }
            isSaving = true
            defer { isSaving = false }
            if await onSave(dateString, value, selectedCurrency) { dismiss() }
            else { saveFailed = true }
        }
    }
}

// MARK: - Previews

#Preview("PriceEditorSheet New") {
    PriceEditorSheet(
        instrument: Instrument(isin: "FR0010315770", ticker: "EWLD.PA", name: "Lyxor MSCI World", currency: "EUR", quadrantId: nil),
        existingPrice: nil,
        onSave: { _, _, _ in true }
    )
}

#Preview("PriceEditorSheet Edit") {
    PriceEditorSheet(
        instrument: Instrument(isin: "FR0010315770", ticker: "EWLD.PA", name: "Lyxor MSCI World", currency: "EUR", quadrantId: nil),
        existingPrice: Price(id: 1, isin: "FR0010315770", date: "2026-03-22", value: 27.40, currency: "EUR"),
        onSave: { _, _, _ in true }
    )
}
