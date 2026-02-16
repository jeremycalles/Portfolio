import SwiftUI

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
            AddHoldingSheet()
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

