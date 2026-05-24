import SwiftUI

// MARK: - iOS All Holdings View
struct iOSAllHoldingsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    @State private var showingAddHoldingSheet = false
    @State private var selectedHolding: HoldingEditItem?
    @State private var searchText = ""
    @State private var selectedAccountId = -1
    @State private var filterMode: HoldingsFilterMode = .all
    @State private var sortMode: HoldingsSortMode = .account
    
    var body: some View {
        let allDetails = getAllHoldingDetails()
        let visibleDetails = filteredAndSortedDetails(from: allDetails)
        let totalPortfolioValue = allDetails.compactMap { $0.currentValueEUR }.reduce(0, +)
        let visibleAccountIds = Set(visibleDetails.map(\.accountId))
        
        List {
            // Period Picker
            Section {
                Picker(L10n.generalComparisonPeriod, selection: $viewModel.selectedPeriod) {
                    ForEach(ReportPeriod.allCases) { period in
                        Text(period.displayName).tag(period)
                    }
                }
            }
            
            Section {
                Picker(L10n.accountsSelectAccount, selection: $selectedAccountId) {
                    Text(L10n.holdingsAllAccounts).tag(-1)
                    ForEach(viewModel.bankAccounts) { account in
                        Text(account.displayName).tag(account.id)
                    }
                }
                
                Picker(L10n.holdingsFilter, selection: $filterMode) {
                    ForEach(HoldingsFilterMode.allCases) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                
                Picker(L10n.holdingsSort, selection: $sortMode) {
                    ForEach(HoldingsSortMode.allCases) { sort in
                        Text(sort.displayName).tag(sort)
                    }
                }
                
                Text(L10n.holdingsShowingCount(visibleDetails.count, allDetails.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                let details = filteredAndSortedDetails(for: account)
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
                                            Text(L10n.holdingsQuantityUnits(formatQuantity(holding.quantity)))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            if !privacyMode, let value = holding.currentValueEUR {
                                                Text(formatCurrency(value, currency: "EUR"))
                                                    .fontWeight(.medium)
                                            } else if privacyMode {
                                                Text("••••••")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Text(L10n.holdingsWeightValue(allocationText(for: holding, totalValue: totalPortfolioValue)))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
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
                                    Label(L10n.generalDelete, systemImage: "trash")
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
                                Text("••••••")
                                    .foregroundColor(.secondary)
                            }
                            if let change = changePercent {
                                ChangeLabel(change: change)
                            }
                        }
                    }
                }
            }
            
            if !viewModel.holdings.isEmpty && visibleAccountIds.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(L10n.holdingsNoMatches)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text(L10n.holdingsAdjustFilters)
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
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
                        Text(L10n.accountsTapToAddHolding)
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: L10n.holdingsSearchPlaceholder)
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
    
    private func getAllHoldingDetails() -> [HoldingDetail] {
        viewModel.bankAccounts.flatMap { viewModel.cachedHoldingDetailsByAccount[$0.id] ?? [] }
    }
    
    private func filteredAndSortedDetails(for account: BankAccount) -> [HoldingDetail] {
        let details = viewModel.cachedHoldingDetailsByAccount[account.id] ?? []
        return filteredAndSortedDetails(from: details, account: account)
    }
    
    private func filteredAndSortedDetails(from details: [HoldingDetail], account: BankAccount? = nil) -> [HoldingDetail] {
        let filtered = details.filter { detail in
            let accountForDetail = account ?? viewModel.bankAccounts.first { $0.id == detail.accountId }
            return matchesAccount(detail)
                && matchesSearch(detail, account: accountForDetail)
                && matchesFilter(detail)
        }
        return sorted(filtered)
    }
    
    private func matchesAccount(_ detail: HoldingDetail) -> Bool {
        selectedAccountId == -1 || detail.accountId == selectedAccountId
    }
    
    private func matchesSearch(_ detail: HoldingDetail, account: BankAccount?) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return true }
        return [
            detail.instrumentName,
            detail.ticker ?? "",
            detail.isin,
            account?.displayName ?? ""
        ].joined(separator: " ").localizedCaseInsensitiveContains(query)
    }
    
    private func matchesFilter(_ detail: HoldingDetail) -> Bool {
        switch filterMode {
        case .all:
            return true
        case .gains:
            return (detail.changePercentEUR ?? 0) > 0
        case .losses:
            return (detail.changePercentEUR ?? 0) < 0
        case .missingPrice:
            return detail.currentValueEUR == nil || detail.currentPrice == nil
        }
    }
    
    private func sorted(_ details: [HoldingDetail]) -> [HoldingDetail] {
        switch sortMode {
        case .account:
            return details.sorted {
                if $0.accountId == $1.accountId { return $0.instrumentName.localizedCaseInsensitiveCompare($1.instrumentName) == .orderedAscending }
                return $0.accountId < $1.accountId
            }
        case .valueDescending:
            return details.sorted { ($0.currentValueEUR ?? -Double.greatestFiniteMagnitude) > ($1.currentValueEUR ?? -Double.greatestFiniteMagnitude) }
        case .valueAscending:
            return details.sorted { ($0.currentValueEUR ?? Double.greatestFiniteMagnitude) < ($1.currentValueEUR ?? Double.greatestFiniteMagnitude) }
        case .performanceDescending:
            return details.sorted { ($0.changePercentEUR ?? -Double.greatestFiniteMagnitude) > ($1.changePercentEUR ?? -Double.greatestFiniteMagnitude) }
        case .performanceAscending:
            return details.sorted { ($0.changePercentEUR ?? Double.greatestFiniteMagnitude) < ($1.changePercentEUR ?? Double.greatestFiniteMagnitude) }
        case .name:
            return details.sorted { $0.instrumentName.localizedCaseInsensitiveCompare($1.instrumentName) == .orderedAscending }
        }
    }
    
    private func allocationText(for detail: HoldingDetail, totalValue: Double) -> String {
        guard totalValue > 0, let value = detail.currentValueEUR else { return L10n.generalNa }
        return String(format: "%.1f%%", (value / totalValue) * 100)
    }
}

// MARK: - Previews

#Preview("iOSAllHoldingsView") {
    NavigationStack {
        iOSAllHoldingsView(privacyMode: false)
            .environmentObject(AppViewModel.preview)
    }
}
