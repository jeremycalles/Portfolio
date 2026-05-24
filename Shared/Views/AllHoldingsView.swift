import SwiftUI

enum HoldingsSortMode: String, CaseIterable, Identifiable {
    case account
    case valueDescending
    case valueAscending
    case performanceDescending
    case performanceAscending
    case name
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .account: return L10n.holdingsSortAccount
        case .valueDescending: return L10n.holdingsSortValueHigh
        case .valueAscending: return L10n.holdingsSortValueLow
        case .performanceDescending: return L10n.holdingsSortPerformanceHigh
        case .performanceAscending: return L10n.holdingsSortPerformanceLow
        case .name: return L10n.holdingsSortName
        }
    }
}

enum HoldingsFilterMode: String, CaseIterable, Identifiable {
    case all
    case gains
    case losses
    case missingPrice
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .all: return L10n.holdingsFilterAll
        case .gains: return L10n.holdingsFilterGains
        case .losses: return L10n.holdingsFilterLosses
        case .missingPrice: return L10n.holdingsFilterMissingPrice
        }
    }
}

// MARK: - All Holdings View (Overview)
struct AllHoldingsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var expandedAccounts: Set<Int> = []
    @State private var holdingToEdit: HoldingEditItem?
    @State private var searchText = ""
    @State private var selectedAccountId = -1
    @State private var filterMode: HoldingsFilterMode = .all
    @State private var sortMode: HoldingsSortMode = .account
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                let allDetails = getAllHoldingDetails()
                let visibleDetails = filteredAndSortedDetails(from: allDetails)
                let totalPortfolioValue = allDetails.compactMap { $0.currentValueEUR }.reduce(0, +)
                let visibleTotalValue = visibleDetails.compactMap { $0.currentValueEUR }.reduce(0, +)
                let visiblePreviousTotal = visibleDetails.compactMap { $0.previousValueEUR }.reduce(0, +)
                
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            TextField(L10n.holdingsSearchPlaceholder, text: $searchText)
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 180, maxWidth: 260)
                            
                            Picker(L10n.accountsSelectAccount, selection: $selectedAccountId) {
                                Text(L10n.holdingsAllAccounts).tag(-1)
                                ForEach(viewModel.bankAccounts) { account in
                                    Text(account.displayName).tag(account.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 220)
                            
                            Picker(L10n.holdingsFilter, selection: $filterMode) {
                                ForEach(HoldingsFilterMode.allCases) { filter in
                                    Text(filter.displayName).tag(filter)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 170)
                            
                            Picker(L10n.holdingsSort, selection: $sortMode) {
                                ForEach(HoldingsSortMode.allCases) { sort in
                                    Text(sort.displayName).tag(sort)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 210)
                            
                            Spacer()
                        }
                        
                        HStack(spacing: 12) {
                            Text(L10n.dashboardComparisonPeriod)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Picker("Period", selection: $viewModel.selectedPeriod) {
                                ForEach(ReportPeriod.allCases) { period in
                                    Text(period.displayName).tag(period)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 400)
                            
                            Spacer()
                            
                            Text(L10n.holdingsShowingCount(visibleDetails.count, allDetails.count))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                }
                .padding(.horizontal)
                
                // Summary (EUR)
                GroupBox {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.dashboardTotalPortfolioValue)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(formatCurrency(visibleTotalValue, currency: "EUR"))
                                .font(.title)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(L10n.accountsHoldingsCount(visibleDetails.count))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if visiblePreviousTotal > 0 {
                                let change = ((visibleTotalValue - visiblePreviousTotal) / visiblePreviousTotal) * 100
                                ChangeLabel(change: change)
                            }
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                // Holdings grouped by account
                let visibleAccounts = viewModel.bankAccounts.filter { selectedAccountId == -1 || $0.id == selectedAccountId }
                let accountsWithVisibleHoldings = visibleAccounts.filter { account in
                    filteredAndSortedDetails(for: account, totalDetails: allDetails).isEmpty == false
                }
                
                if accountsWithVisibleHoldings.isEmpty {
                    GroupBox {
                        VStack(spacing: 8) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary)
                            Text(L10n.holdingsNoMatches)
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text(L10n.holdingsAdjustFilters)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                    }
                    .padding(.horizontal)
                }
                
                ForEach(accountsWithVisibleHoldings) { account in
                    let details = filteredAndSortedDetails(for: account, totalDetails: allDetails)
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
                                        Text(L10n.holdingsWeight)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(width: 80, alignment: .trailing)
                                        Text(L10n.holdingsChange)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(width: 80, alignment: .trailing)
                                    }
                                    .padding(.vertical, 8)
                                    
                                    Divider()
                                    
                                    // Holdings
                                    ForEach(details) { detail in
                                        Button {
                                            holdingToEdit = HoldingEditItem(accountId: account.id, isin: detail.isin)
                                        } label: {
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
                                                
                                                Text(allocationText(for: detail, totalValue: totalPortfolioValue))
                                                    .font(.body)
                                                    .foregroundColor(.secondary)
                                                    .frame(width: 80, alignment: .trailing)
                                                
                                                if let change = detail.changePercentEUR {
                                                    ChangeLabel(change: change)
                                                        .frame(width: 80, alignment: .trailing)
                                                } else {
                                                    Text("—")
                                                        .foregroundColor(.secondary)
                                                        .frame(width: 80, alignment: .trailing)
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 6)
                                        .contentShape(Rectangle())
                                        
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
        .sheet(item: $holdingToEdit) { item in
            NavigationStack {
                EditHoldingView(accountId: item.accountId, isin: item.isin)
                    .environmentObject(viewModel)
            }
            .frame(minWidth: 420, minHeight: 380)
        }
        .onAppear {
            // Expand all accounts by default
            expandedAccounts = Set(viewModel.bankAccounts.map { $0.id })
        }
    }
    
    private func getAllHoldingDetails() -> [HoldingDetail] {
        viewModel.bankAccounts.flatMap { viewModel.cachedHoldingDetailsByAccount[$0.id] ?? [] }
    }
    
    private func filteredAndSortedDetails(for account: BankAccount, totalDetails: [HoldingDetail]) -> [HoldingDetail] {
        let accountDetails = viewModel.cachedHoldingDetailsByAccount[account.id] ?? []
        return filteredAndSortedDetails(from: accountDetails, account: account, allDetails: totalDetails)
    }
    
    private func filteredAndSortedDetails(from details: [HoldingDetail], account: BankAccount? = nil, allDetails: [HoldingDetail]? = nil) -> [HoldingDetail] {
        let source = allDetails == nil ? details.filter { selectedAccountId == -1 || $0.accountId == selectedAccountId } : details
        let filtered = source.filter { detail in
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
        let haystack = [
            detail.instrumentName,
            detail.ticker ?? "",
            detail.isin,
            account?.displayName ?? ""
        ].joined(separator: " ").localizedCaseInsensitiveContains(query)
        return haystack
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

#Preview("AllHoldingsView") {
    NavigationStack {
        AllHoldingsView()
            .environmentObject(AppViewModel.preview)
    }
}
