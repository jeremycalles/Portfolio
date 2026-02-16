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
                LabeledContent(L10n.accountsTitle, value: accountName)
                LabeledContent(L10n.holdingsInstrument, value: instrumentName)
            }
            #else
            Section(L10n.accountsTitle) {
                Text(accountName)
                    .foregroundColor(.secondary)
            }
            Section(L10n.holdingsInstrument) {
                Text(instrumentName)
                    .foregroundColor(.secondary)
            }
            #endif
            Section(L10n.holdingsQty) {
                TextField(L10n.holdingsQty, text: $quantityText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            }
            Section {
                Toggle(L10n.holdingsPurchaseDetailsHint, isOn: $includePurchaseInfo)
                if includePurchaseInfo {
                    DatePicker(L10n.holdingsPurchaseDetails, selection: $purchaseDate, displayedComponents: .date)
                    TextField(L10n.holdingsPurchaseDetails, text: $purchasePriceText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
            } header: {
                Text(L10n.holdingsPurchaseDetails)
            } footer: {
                Text(L10n.holdingsPurchaseDetailsHint)
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        .frame(minWidth: 400)
        #endif
        .navigationTitle(L10n.holdingsEditHolding)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.generalCancel) {
                    dismiss()
                }
                #if os(macOS)
                .keyboardShortcut(.cancelAction)
                #endif
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.generalSave) {
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
