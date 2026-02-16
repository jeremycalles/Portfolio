import SwiftUI

#if os(macOS)
// MARK: - Bank Accounts View
struct BankAccountsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingAddSheet = false
    @State private var newBankName = ""
    @State private var newAccountName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Spacer()
                
                Button {
                    showingAddSheet = true
                } label: {
                    Label(L10n.accountsAddAccount, systemImage: "plus")
                }
            }
            .padding()
            
            Divider()
            
            List {
                ForEach(viewModel.bankAccounts) { account in
                    let holdingCount = viewModel.holdings.filter { $0.accountId == account.id }.count
                    
                    HStack {
                        Image(systemName: "building.columns.fill")
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading) {
                            Text(account.bankName)
                                .font(.headline)
                            Text(account.accountName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(L10n.accountsHoldingsCount(holdingCount))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button {
                            viewModel.deleteBankAccount(id: account.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(L10n.accountsBankAccountsCount(viewModel.bankAccounts.count))
        .sheet(isPresented: $showingAddSheet) {
            VStack(spacing: 20) {
                Text(L10n.accountsAddAccount)
                    .font(.headline)
                
                TextField("Bank Name", text: $newBankName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                
                TextField("Account Name", text: $newAccountName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                
                HStack {
                    Button(L10n.generalCancel) {
                        showingAddSheet = false
                        newBankName = ""
                        newAccountName = ""
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    Button(L10n.generalAdd) {
                        viewModel.addBankAccount(
                            bank: newBankName.trimmingCharacters(in: .whitespaces),
                            account: newAccountName.trimmingCharacters(in: .whitespaces)
                        )
                        showingAddSheet = false
                        newBankName = ""
                        newAccountName = ""
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(
                        newBankName.trimmingCharacters(in: .whitespaces).isEmpty ||
                        newAccountName.trimmingCharacters(in: .whitespaces).isEmpty
                    )
                }
            }
            .padding(30)
        }
    }
}

// MARK: - Holdings View
struct HoldingsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingAddSheet = false
    @State private var holdingToEdit: HoldingEditItem?
    @State private var selectedAccount: BankAccount?
    @State private var selectedInstrument: Instrument?
    @State private var quantity: String = ""
    @State private var purchasePrice: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Spacer()
                
                Button {
                    showingAddSheet = true
                } label: {
                    Label(L10n.holdingsAddHolding, systemImage: "plus")
                }
                .disabled(viewModel.bankAccounts.isEmpty || viewModel.instruments.isEmpty)
            }
            .padding()
            
            Divider()
            
            if viewModel.bankAccounts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "building.columns")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(L10n.accountsNoBankAccounts)
                        .font(.headline)
                    Text(L10n.accountsAddBankAccountFirst)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.bankAccounts) { account in
                        Section(header: Text(account.displayName)) {
                            let accountHoldings = viewModel.holdings.filter { $0.accountId == account.id }
                            
                            if accountHoldings.isEmpty {
                                Text(L10n.holdingsNoHoldings)
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(accountHoldings, id: \.isin) { holding in
                                    if let instrument = viewModel.instruments.first(where: { $0.isin == holding.isin }) {
                                        Button {
                                            holdingToEdit = HoldingEditItem(accountId: account.id, isin: holding.isin)
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading) {
                                                    Text(instrument.displayName)
                                                        .lineLimit(1)
                                                    Text(holding.isin)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                
                                                Spacer()
                                                
                                                VStack(alignment: .trailing) {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "pencil")
                                                            .font(.body)
                                                            .foregroundColor(.secondary)
                                                        Text(formatQuantity(holding.quantity))
                                                            .font(.headline)
                                                    }
                                                    if let price = holding.purchasePrice {
                                                        Text("@ \(formatQuantity(price))")
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                
                                                Button {
                                                    viewModel.deleteHolding(accountId: account.id, isin: holding.isin)
                                                } label: {
                                                    Image(systemName: "trash")
                                                        .foregroundColor(.red)
                                                }
                                                .buttonStyle(.borderless)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.accountsHoldingsCountTitle(viewModel.holdings.count))
        .sheet(isPresented: $showingAddSheet) {
            AddHoldingSheet(
                isPresented: $showingAddSheet,
                selectedAccount: $selectedAccount,
                selectedInstrument: $selectedInstrument,
                quantity: $quantity,
                purchasePrice: $purchasePrice
            )
        }
        .sheet(item: $holdingToEdit) { item in
            NavigationStack {
                EditHoldingView(accountId: item.accountId, isin: item.isin)
                    .environmentObject(viewModel)
            }
            .frame(minWidth: 420, minHeight: 380)
        }
    }
}

// MARK: - Add Holding Sheet
struct AddHoldingSheet: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Binding var isPresented: Bool
    @Binding var selectedAccount: BankAccount?
    @Binding var selectedInstrument: Instrument?
    @Binding var quantity: String
    @Binding var purchasePrice: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text(L10n.holdingsAddHolding)
                .font(.headline)
            
            Form {
                Picker("Bank Account", selection: $selectedAccount) {
                    Text(L10n.accountsSelectAccount).tag(nil as BankAccount?)
                    ForEach(viewModel.bankAccounts) { account in
                        Text(account.displayName).tag(account as BankAccount?)
                    }
                }
                
                Picker("Instrument", selection: $selectedInstrument) {
                    Text(L10n.holdingsSelectInstrument).tag(nil as Instrument?)
                    ForEach(viewModel.instruments) { instrument in
                        Text(instrument.displayName).tag(instrument as Instrument?)
                    }
                }
                
                TextField("Quantity", text: $quantity)
                
                TextField("Purchase Price (optional)", text: $purchasePrice)
            }
            .frame(width: 350)
            
            HStack {
                Button(L10n.generalCancel) {
                    resetAndClose()
                }
                .keyboardShortcut(.cancelAction)
                
                Button(L10n.generalAdd) {
                    if let account = selectedAccount,
                       let instrument = selectedInstrument,
                       let qty = Double(quantity) {
                        viewModel.addHolding(
                            accountId: account.id,
                            isin: instrument.isin,
                            quantity: qty,
                            purchaseDate: nil,
                            purchasePrice: Double(purchasePrice)
                        )
                        resetAndClose()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    selectedAccount == nil ||
                    selectedInstrument == nil ||
                    Double(quantity) == nil
                )
            }
        }
        .padding(30)
        .frame(minWidth: 400)
    }
    
    private func resetAndClose() {
        isPresented = false
        selectedAccount = nil
        selectedInstrument = nil
        quantity = ""
        purchasePrice = ""
    }
}
#endif
