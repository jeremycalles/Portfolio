import SwiftUI

// MARK: - Shared Add Holding Sheet
struct AddHoldingSheet: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedAccountId: Int?
    @State private var selectedIsin: String?
    @State private var quantityText = ""
    @State private var purchasePriceText = ""
    @State private var purchaseDate = Date()
    @State private var includePurchaseInfo = false
    
    private var isValid: Bool {
        guard let _ = selectedAccountId,
              let _ = selectedIsin,
              let quantity = parseDecimal(quantityText),
              quantity > 0 else {
            return false
        }
        return true
    }
    
    var body: some View {
        #if os(iOS)
        NavigationStack {
            formContent
                .navigationTitle(L10n.holdingsAddHolding)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.generalCancel) {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.generalAdd) {
                            addHolding()
                        }
                        .disabled(!isValid)
                    }
                }
        }
        #else
        VStack(spacing: 20) {
            Text(L10n.holdingsAddHolding)
                .font(.headline)
            
            formContent
                .frame(width: 350)
            
            HStack {
                Button(L10n.generalCancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button(L10n.generalAdd) {
                    addHolding()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(30)
        .frame(minWidth: 400)
        #endif
    }
    
    private var formContent: some View {
        Form {
            // Account Selection
            Section(L10n.accountsSelectAnAccount) {
                Picker(L10n.accountsSelectAccount, selection: $selectedAccountId) {
                    Text(L10n.accountsSelectAnAccount).tag(nil as Int?)
                    ForEach(viewModel.bankAccounts) { account in
                        Text(account.displayName).tag(account.id as Int?)
                    }
                }
                #if os(iOS)
                .pickerStyle(.menu)
                #endif
            }
            
            // Instrument Selection
            Section(L10n.holdingsInstrument) {
                Picker(L10n.holdingsSelectInstrument, selection: $selectedIsin) {
                    Text(L10n.holdingsSelectAnInstrument).tag(nil as String?)
                    ForEach(viewModel.instruments) { instrument in
                        Text(instrument.displayName).tag(instrument.isin as String?)
                    }
                }
                #if os(iOS)
                .pickerStyle(.menu)
                #endif
            }
            
            // Quantity
            Section(L10n.holdingsQty) {
                TextField(L10n.holdingsQty, text: $quantityText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            }
            
            // Optional Purchase Info
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
            }
        }
        .onAppear {
            // Pre-select first account and instrument if available
            if selectedAccountId == nil, let firstAccount = viewModel.bankAccounts.first {
                selectedAccountId = firstAccount.id
            }
            if selectedIsin == nil, let firstInstrument = viewModel.instruments.first {
                selectedIsin = firstInstrument.isin
            }
        }
    }
    
    private func addHolding() {
        guard let accountId = selectedAccountId,
              let isin = selectedIsin,
              let quantity = parseDecimal(quantityText),
              quantity > 0 else {
            return
        }
        
        let purchasePrice = includePurchaseInfo ? parseDecimal(purchasePriceText) : nil
        let purchaseDateStr = includePurchaseInfo ? AppDateFormatter.yearMonthDay.string(from: purchaseDate) : nil
        
        viewModel.addHolding(
            accountId: accountId,
            isin: isin,
            quantity: quantity,
            purchaseDate: purchaseDateStr,
            purchasePrice: purchasePrice
        )
        
        dismiss()
    }
}
