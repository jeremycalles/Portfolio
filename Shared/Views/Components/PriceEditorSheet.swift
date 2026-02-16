import SwiftUI

// MARK: - Shared Price Editor Sheet
struct PriceEditorSheet: View {
    let instrument: Instrument
    let existingPrice: Price?
    let onSave: (String, Double, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date
    @State private var priceText: String
    @State private var selectedCurrency: String
    
    private let currencies = ["EUR", "USD", "GBP", "CHF", "JPY"]
    
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
        guard let value = parseDecimal(priceText), value > 0 else { return false }
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
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(existingPrice == nil ? L10n.generalAdd : L10n.generalSave) {
                            savePrice()
                        }
                        .disabled(!isValid)
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
                    savePrice()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 350, height: 280)
        #endif
    }
    
    private var formContent: some View {
        Form {
            Section(L10n.instrumentsPriceDetails) {
                DatePicker(L10n.reportsDate, selection: $selectedDate, displayedComponents: .date)
                
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
    }
    
    private func savePrice() {
        if let value = parseDecimal(priceText) {
            let dateString = AppDateFormatter.yearMonthDay.string(from: selectedDate)
            onSave(dateString, value, selectedCurrency)
            dismiss()
        }
    }
}
