import SwiftUI

// MARK: - All Holdings View (Overview)
struct AllHoldingsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var expandedAccounts: Set<Int> = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Period Picker
                HStack(spacing: 12) {
                    Text(L10n.dashboardComparisonPeriod)
                        .font(.headline)
                    Picker("Period", selection: $viewModel.selectedPeriod) {
                        ForEach(ReportPeriod.allCases) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 400)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Summary (EUR)
                let allDetails = getAllHoldingDetails()
                let totalValue = allDetails.compactMap { $0.currentValueEUR }.reduce(0, +)
                let totalPrevious = allDetails.compactMap { $0.previousValueEUR }.reduce(0, +)
                
                GroupBox {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.dashboardTotalPortfolioValue)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(formatCurrency(totalValue, currency: "EUR"))
                                .font(.title)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(L10n.accountsHoldingsCount(allDetails.count))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if totalPrevious > 0 {
                                let change = ((totalValue - totalPrevious) / totalPrevious) * 100
                                ChangeLabel(change: change)
                            }
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                // Holdings grouped by account
                ForEach(viewModel.bankAccounts) { account in
                    let details = viewModel.getHoldingDetails(forAccount: account.id)
                    let accountTotal = details.compactMap { $0.currentValueEUR }.reduce(0, +)
                    let accountPreviousTotal = details.compactMap { $0.previousValueEUR }.reduce(0, +)
                    
                    GroupBox {
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedAccounts.contains(account.id) },
                                set: { isExpanded in
                                    if isExpanded {
                                        expandedAccounts.insert(account.id)
                                    } else {
                                        expandedAccounts.remove(account.id)
                                    }
                                }
                            )
                        ) {
                            if details.isEmpty {
                                Text(L10n.accountsNoHoldingsInAccount)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                VStack(spacing: 0) {
                                    // Header
                                    HStack {
                                        Text(L10n.holdingsInstrument)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(L10n.holdingsQty)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(width: 80, alignment: .trailing)
                                        Text(L10n.holdingsValue)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(width: 120, alignment: .trailing)
                                        Text(L10n.holdingsChange)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(width: 80, alignment: .trailing)
                                    }
                                    .padding(.vertical, 8)
                                    
                                    Divider()
                                    
                                    // Holdings
                                    ForEach(details) { detail in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(detail.instrumentName)
                                                    .font(.body)
                                                    .lineLimit(1)
                                                if let ticker = detail.ticker {
                                                    Text(ticker)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            
                                            Text(formatQuantity(detail.quantity))
                                                .font(.body)
                                                .frame(width: 80, alignment: .trailing)
                                            
                                            if let value = detail.currentValueEUR {
                                                Text(formatCurrency(value, currency: "EUR"))
                                                    .font(.body)
                                                    .frame(width: 120, alignment: .trailing)
                                            } else {
                                                Text(L10n.generalNa)
                                                    .foregroundColor(.secondary)
                                                    .frame(width: 120, alignment: .trailing)
                                            }
                                            
                                            if let change = detail.changePercentEUR {
                                                ChangeLabel(change: change)
                                                    .frame(width: 80, alignment: .trailing)
                                            } else {
                                                Text("—")
                                                    .foregroundColor(.secondary)
                                                    .frame(width: 80, alignment: .trailing)
                                            }
                                        }
                                        .padding(.vertical, 6)
                                        
                                        if detail.id != details.last?.id {
                                            Divider()
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(account.displayName)
                                        .font(.headline)
                                    Text(L10n.accountsHoldingsCount(details.count))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(formatCurrency(accountTotal, currency: "EUR"))
                                        .font(.headline)
                                    if accountPreviousTotal > 0 {
                                        let change = ((accountTotal - accountPreviousTotal) / accountPreviousTotal) * 100
                                        ChangeLabel(change: change)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.vertical)
        }
        .navigationTitle(L10n.navAllHoldings)
        .onAppear {
            // Expand all accounts by default
            expandedAccounts = Set(viewModel.bankAccounts.map { $0.id })
        }
    }
    
    private func getAllHoldingDetails() -> [HoldingDetail] {
        var allDetails: [HoldingDetail] = []
        for account in viewModel.bankAccounts {
            allDetails.append(contentsOf: viewModel.getHoldingDetails(forAccount: account.id))
        }
        return allDetails
    }
}
