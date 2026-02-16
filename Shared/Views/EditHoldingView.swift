import SwiftUI

// MARK: - Edit Holding View (shared: iOS NavigationLink destination, macOS sheet)
struct EditHoldingView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    let accountId: Int
    let isin: String
    
    @State private var quantityText = ""
    @State private var purchasePriceText = ""
    @State private var purchaseDate = Date()
    @State private var includePurchaseInfo = false
    
    private var existingHolding: Holding? {
        viewModel.holdings.first { $0.accountId == accountId && $0.isin == isin }
    }
    
    private var accountName: String {
        viewModel.bankAccounts.first { $0.id == accountId }?.displayName ?? ""
    }
    
    private var instrumentName: String {
        viewModel.instruments.first { $0.isin == isin }?.displayName ?? isin
    }
    
    private var isValid: Bool {
        parseDecimal(quantityText).map { $0 > 0 } ?? false
    }
    
    var body: some View {
        Form {
            #if os(macOS)
            Section {
                LabeledContent("Account", value: accountName)
                LabeledContent("Instrument", value: instrumentName)
            }
            #else
            Section("Account") {
                Text(accountName)
                    .foregroundColor(.secondary)
            }
            Section("Instrument") {
                Text(instrumentName)
                    .foregroundColor(.secondary)
            }
            #endif
            Section("Quantity") {
                TextField("Number of units", text: $quantityText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            }
            Section {
                Toggle("Include Purchase Info", isOn: $includePurchaseInfo)
                if includePurchaseInfo {
                    DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
                    TextField("Purchase Price (per unit)", text: $purchasePriceText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
            } header: {
                Text("Purchase Details")
            } footer: {
                Text("Optional: Track your cost basis for performance calculation")
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        .frame(minWidth: 400)
        #endif
        .navigationTitle("Edit Position")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                #if os(macOS)
                .keyboardShortcut(.cancelAction)
                #endif
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(!isValid)
                #if os(macOS)
                .keyboardShortcut(.defaultAction)
                #endif
            }
        }
        .onAppear {
            if let h = existingHolding {
                quantityText = String(format: "%.4f", h.quantity)
                includePurchaseInfo = h.purchaseDate != nil || h.purchasePrice != nil
                if let dateStr = h.purchaseDate, let d = AppDateFormatter.yearMonthDay.date(from: dateStr) {
                    purchaseDate = d
                }
                if let p = h.purchasePrice {
                    purchasePriceText = String(format: "%.4f", p)
                }
            }
        }
    }
    
    private func save() {
        guard let quantity = parseDecimal(quantityText), quantity > 0 else { return }
        let purchaseDateStr: String? = includePurchaseInfo ? AppDateFormatter.yearMonthDay.string(from: purchaseDate) : nil
        let purchasePrice: Double? = includePurchaseInfo ? parseDecimal(purchasePriceText) : nil
        viewModel.updateHolding(accountId: accountId, isin: isin, quantity: quantity, purchaseDate: purchaseDateStr, purchasePrice: purchasePrice)
        dismiss()
    }
}
