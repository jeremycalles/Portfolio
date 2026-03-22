import SwiftUI

// MARK: - iOS All Holdings View
struct iOSAllHoldingsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    @State private var showingAddHoldingSheet = false
    @State private var selectedHolding: HoldingEditItem?
    
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
            
            // Hint when Add is disabled (no instruments or no bank accounts)
            if viewModel.instruments.isEmpty || viewModel.bankAccounts.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        if viewModel.instruments.isEmpty {
                            Text(L10n.accountsAddInstrumentFirst)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        if viewModel.bankAccounts.isEmpty {
                            Text(L10n.accountsAddBankAccountFirst)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                }
            }
            
            // Holdings grouped by account
            ForEach(viewModel.bankAccounts) { account in
                let details = viewModel.cachedHoldingDetailsByAccount[account.id] ?? []
                if !details.isEmpty {
                    Section(account.displayName) {
                        ForEach(details) { holding in
                            Button {
                                selectedHolding = HoldingEditItem(accountId: account.id, isin: holding.isin)
                            } label: {
                                HStack {
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
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteHolding(accountId: account.id, isin: holding.isin) }
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
        .navigationDestination(item: $selectedHolding) { item in
            EditHoldingView(accountId: item.accountId, isin: item.isin)
        }
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

// MARK: - Previews

#Preview("iOSAllHoldingsView") {
    NavigationStack {
        iOSAllHoldingsView(privacyMode: false)
            .environmentObject(AppViewModel.preview)
    }
}
