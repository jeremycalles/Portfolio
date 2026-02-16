import SwiftUI

// MARK: - iOS All Holdings View
struct iOSAllHoldingsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    @State private var showingAddHoldingSheet = false
    
    var body: some View {
        List {
            // Period Picker
            Section {
                Picker(L10n.generalComparisonPeriod, selection: $viewModel.selectedPeriod) {
                    ForEach(ReportPeriod.allCases) { period in
                        Text(period.displayName).tag(period)
                    }
                }
            }
            
            // Holdings grouped by account
            ForEach(viewModel.bankAccounts) { account in
                let details = viewModel.getHoldingDetails(forAccount: account.id)
                if !details.isEmpty {
                    Section(account.displayName) {
                        ForEach(details) { holding in
                            NavigationLink {
                                EditHoldingView(accountId: account.id, isin: holding.isin)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(holding.instrumentName)
                                            .font(.headline)
                                        Spacer()
                                        if let change = holding.changePercentEUR {
                                            ChangeLabel(change: change)
                                        }
                                    }
                                    
                                    HStack {
                                        Text("\(holding.quantity, specifier: "%.4f") units")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        if !privacyMode, let value = holding.currentValueEUR {
                                            Text(formatCurrency(value, currency: "EUR"))
                                                .fontWeight(.medium)
                                        } else if privacyMode {
                                            Text("***")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .padding(.vertical, 4)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.deleteHolding(accountId: account.id, isin: holding.isin)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        
                        // Account Total (EUR)
                        let totalValue = details.compactMap { $0.currentValueEUR }.reduce(0, +)
                        let totalPreviousValue = details.compactMap { $0.previousValueEUR }.reduce(0, +)
                        let changePercent: Double? = totalPreviousValue > 0 ? ((totalValue - totalPreviousValue) / totalPreviousValue) * 100 : nil
                        
                        HStack {
                            Text("Total (EUR)")
                                .fontWeight(.semibold)
                            Spacer()
                            if !privacyMode {
                                Text(formatCurrency(totalValue, currency: "EUR"))
                                    .fontWeight(.bold)
                            } else {
                                Text("***")
                                    .foregroundColor(.secondary)
                            }
                            if let change = changePercent {
                                ChangeLabel(change: change)
                            }
                        }
                    }
                }
            }
            
            // Empty state
            if viewModel.holdings.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(L10n.accountsNoHoldingsYet)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Tap + to add your first holding")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.startRefreshTask(showCompletionDelay: false).value
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddHoldingSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(viewModel.bankAccounts.isEmpty || viewModel.instruments.isEmpty)
            }
        }
        .sheet(isPresented: $showingAddHoldingSheet) {
            AddHoldingSheet()
        }
    }
}

// MARK: - Add Holding Sheet
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
        NavigationStack {
            Form {
                // Account Selection
                Section("Account") {
                    Picker("Select Account", selection: $selectedAccountId) {
                        Text("Select an account").tag(nil as Int?)
                        ForEach(viewModel.bankAccounts) { account in
                            Text(account.displayName).tag(account.id as Int?)
                        }
                    }
                }
                
                // Instrument Selection
                Section("Instrument") {
                    Picker("Select Instrument", selection: $selectedIsin) {
                        Text("Select an instrument").tag(nil as String?)
                        ForEach(viewModel.instruments) { instrument in
                            Text(instrument.displayName).tag(instrument.isin as String?)
                        }
                    }
                }
                
                // Quantity
                Section("Quantity") {
                    TextField("Number of units", text: $quantityText)
                        .keyboardType(.decimalPad)
                }
                
                // Optional Purchase Info
                Section {
                    Toggle("Include Purchase Info", isOn: $includePurchaseInfo)
                    
                    if includePurchaseInfo {
                        DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
                        
                        TextField("Purchase Price (per unit)", text: $purchasePriceText)
                            .keyboardType(.decimalPad)
                    }
                } header: {
                    Text("Purchase Details")
                } footer: {
                    Text("Optional: Track your cost basis for performance calculation")
                }
            }
            .navigationTitle(L10n.holdingsAddHolding)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addHolding()
                    }
                    .disabled(!isValid)
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
    }
    
    private func addHolding() {
        guard let accountId = selectedAccountId,
              let isin = selectedIsin,
              let quantity = parseDecimal(quantityText) else {
            return
        }
        
        let purchaseDateStr: String? = includePurchaseInfo ? AppDateFormatter.yearMonthDay.string(from: purchaseDate) : nil
        let purchasePrice: Double? = includePurchaseInfo ? parseDecimal(purchasePriceText) : nil
        
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
