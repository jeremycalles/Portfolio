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
    @State private var showingFilterSheet = false
    
    var body: some View {
        if #available(iOS 26.0, *) {
            liquidGlassBody
        } else {
            legacyBody
        }
    }

    private var legacyBody: some View {
        List {
            holdingsRows(showFilterRows: true)
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
                addHoldingButton
            }
        }
        .sheet(isPresented: $showingAddHoldingSheet) {
            AddHoldingSheet()
        }
    }

    @available(iOS 26.0, *)
    private var liquidGlassBody: some View {
        let allDetails = getAllHoldingDetails()
        let visibleDetails = filteredAndSortedDetails(from: allDetails)
        let visibleValue = visibleDetails.compactMap { $0.currentValueEUR }.reduce(0, +)

        return List {
            holdingsRows(showFilterRows: false)
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
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingFilterSheet = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel(L10n.holdingsFilter)

                addHoldingButton
            }
        }
        .safeAreaInset(edge: .bottom) {
            iOSHoldingsFilterBar(
                visibleCount: visibleDetails.count,
                totalCount: allDetails.count,
                visibleValue: privacyMode ? nil : visibleValue,
                accountName: selectedAccountName,
                filterName: filterMode.displayName,
                sortName: sortMode.displayName,
                onTap: { showingFilterSheet = true }
            )
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showingAddHoldingSheet) {
            AddHoldingSheet()
        }
        .sheet(isPresented: $showingFilterSheet) {
            NavigationStack {
                Form {
                    holdingsFilterControls
                }
                .navigationTitle(L10n.holdingsFilter)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.generalDone) {
                            showingFilterSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private func holdingsRows(showFilterRows: Bool) -> some View {
        let allDetails = getAllHoldingDetails()
        let visibleDetails = filteredAndSortedDetails(from: allDetails)
        let totalPortfolioValue = allDetails.compactMap { $0.currentValueEUR }.reduce(0, +)
        let visibleAccountIds = Set(visibleDetails.map(\.accountId))

        if showFilterRows {
            Section {
                Picker(L10n.generalComparisonPeriod, selection: $viewModel.selectedPeriod) {
                    ForEach(ReportPeriod.allCases) { period in
                        Text(period.displayName).tag(period)
                    }
                }
            }
            
            Section {
                holdingsFilterControls
                
                Text(L10n.holdingsShowingCount(visibleDetails.count, allDetails.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                        Text(L10n.summaryTotalEur)
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

    @ViewBuilder
    private var holdingsFilterControls: some View {
        Picker(L10n.generalComparisonPeriod, selection: $viewModel.selectedPeriod) {
            ForEach(ReportPeriod.allCases) { period in
                Text(period.displayName).tag(period)
            }
        }
        
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
    }

    private var addHoldingButton: some View {
        Button {
            showingAddHoldingSheet = true
        } label: {
            Image(systemName: "plus")
        }
        .disabled(viewModel.bankAccounts.isEmpty || viewModel.instruments.isEmpty)
    }

    private var selectedAccountName: String {
        guard selectedAccountId != -1,
              let account = viewModel.bankAccounts.first(where: { $0.id == selectedAccountId }) else {
            return L10n.holdingsAllAccounts
        }
        return account.displayName
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

@available(iOS 26.0, *)
private struct iOSHoldingsFilterBar: View {
    let visibleCount: Int
    let totalCount: Int
    let visibleValue: Double?
    let accountName: String
    let filterName: String
    let sortName: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(L10n.holdingsShowingCount(visibleCount, totalCount))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                        if let visibleValue {
                            Text(formatCompactCurrency(visibleValue))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("\(accountName) • \(filterName) • \(sortName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .portfolioGlassSurface(cornerRadius: 18, interactive: true)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("iOSAllHoldingsView") {
    NavigationStack {
        iOSAllHoldingsView(privacyMode: false)
            .environmentObject(AppViewModel.preview)
    }
}
