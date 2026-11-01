import SwiftUI

struct iOSAllHoldingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dynamicTypeSize) private var typeSize
    let privacyMode: Bool
    @State private var showingAdd = false
    @State private var showingFilters = false
    @State private var searchText = ""
    @State private var selectedAccountId: Int
    @State private var filterMode: HoldingsFilterMode
    @State private var sortMode: HoldingsSortMode = .valueDescending
    @State private var groupByAccount = false
    @State private var closingPosition: HoldingEditItem?

    init(privacyMode: Bool, initialFilter: HoldingsFilterMode = .all, accountId: Int? = nil) {
        self.privacyMode = privacyMode
        _filterMode = State(initialValue: initialFilter)
        _selectedAccountId = State(initialValue: accountId ?? -1)
    }

    private var allDetails: [HoldingDetail] { viewModel.cachedHoldingDetailsByAccount.values.flatMap { $0 } }
    private var visibleDetails: [HoldingDetail] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return allDetails.filter { detail in
            let account = viewModel.bankAccounts.first { $0.id == detail.accountId }?.displayName ?? ""
            let matchesSearch = query.isEmpty || [detail.instrumentName, detail.isin, detail.ticker ?? "", account].joined(separator: " ").localizedCaseInsensitiveContains(query)
            let matchesAccount = selectedAccountId == -1 || detail.accountId == selectedAccountId
            let change = viewModel.cachedPositionTWR[detail.id]
            let matchesFilter: Bool
            switch filterMode {
            case .all: matchesFilter = true
            case .gains: matchesFilter = change.map { $0 > 0 } ?? false
            case .losses: matchesFilter = change.map { $0 < 0 } ?? false
            case .missingPrice: matchesFilter = detail.currentValueEUR == nil
            }
            return matchesSearch && matchesAccount && matchesFilter
        }.sorted { a, b in
            switch sortMode {
            case .account:
                if a.accountId != b.accountId { return a.accountId < b.accountId }
                return a.instrumentName.localizedStandardCompare(b.instrumentName) == .orderedAscending
            case .name: return a.instrumentName.localizedStandardCompare(b.instrumentName) == .orderedAscending
            case .valueDescending: return (a.currentValueEUR ?? -.infinity) > (b.currentValueEUR ?? -.infinity)
            case .valueAscending: return (a.currentValueEUR ?? .infinity) < (b.currentValueEUR ?? .infinity)
            case .performanceDescending: return (viewModel.cachedPositionTWR[a.id] ?? -.infinity) > (viewModel.cachedPositionTWR[b.id] ?? -.infinity)
            case .performanceAscending: return (viewModel.cachedPositionTWR[a.id] ?? .infinity) < (viewModel.cachedPositionTWR[b.id] ?? .infinity)
            }
        }
    }

    var body: some View {
        List {
            Section {
                Picker(L10n.designPeriod, selection: $viewModel.selectedPeriod) {
                    ForEach(ReportPeriod.allCases) { Text($0.displayName).tag($0) }
                }
                Button { showingFilters = true } label: {
                    let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())
                    layout {
                        Label(L10n.holdingsFilter, systemImage: "line.3.horizontal.decrease")
                        if !typeSize.isAccessibilitySize { Spacer() }
                        Text(filterMode == .all ? sortMode.displayName : filterMode.displayName)
                            .font(.subheadline).foregroundStyle(Color.secondary)
                    }
                }
            } footer: { Text(L10n.holdingsShowingCount(visibleDetails.count, allDetails.count)) }

            if allDetails.isEmpty {
                ContentUnavailableView {
                    Label(L10n.accountsNoHoldingsYet, systemImage: "wallet.bifold")
                } description: { Text(L10n.designWelcomeMessage) } actions: {
                    Button(L10n.designFirstHolding) { showingAdd = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.demoMode.isDemoModeEnabled)
                }
            } else if visibleDetails.isEmpty {
                ContentUnavailableView {
                    Label(L10n.holdingsNoMatches, systemImage: "magnifyingglass")
                } actions: { Button(L10n.designResetFilters, action: resetFilters) }
            } else if groupByAccount {
                ForEach(viewModel.bankAccounts) { account in
                    let rows = visibleDetails.filter { $0.accountId == account.id }
                    if !rows.isEmpty {
                        Section(account.displayName) { ForEach(rows, content: holdingRow) }
                    }
                }
            } else {
                Section { ForEach(visibleDetails, content: holdingRow) }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: L10n.holdingsSearchPlaceholder)
        .refreshable { await viewModel.startRefreshTask(showCompletionDelay: false).value }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    NavigationLink(L10n.designClosedPositions) { iOSClosedPositionsView() }
                    NavigationLink(L10n.designManageInstruments) { iOSInstrumentsView().navigationTitle(L10n.navInstruments) }
                    NavigationLink(L10n.designManageAccounts) { iOSAccountsManagementView() }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel(L10n.generalManage)
                Button { showingAdd = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel(L10n.holdingsAddHolding)
                    .disabled(viewModel.demoMode.isDemoModeEnabled)
            }
        }
        .sheet(isPresented: $showingAdd) { AddHoldingSheet() }
        .sheet(isPresented: $showingFilters) {
            NavigationStack {
                Form {
                    Picker(L10n.accountsSelectAccount, selection: $selectedAccountId) {
                        Text(L10n.holdingsAllAccounts).tag(-1)
                        ForEach(viewModel.bankAccounts) { Text($0.displayName).tag($0.id) }
                    }
                    Picker(L10n.holdingsFilter, selection: $filterMode) {
                        ForEach(HoldingsFilterMode.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker(L10n.holdingsSort, selection: $sortMode) {
                        ForEach(HoldingsSortMode.allCases) { Text($0.displayName).tag($0) }
                    }
                    Toggle(L10n.designGroupByAccount, isOn: $groupByAccount)
                    Button(L10n.designResetFilters, action: resetFilters)
                }
                .navigationTitle(L10n.holdingsFilter).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.generalDone) { showingFilters = false } } }
            }.presentationDetents([.medium, .large])
        }
        .confirmationDialog(L10n.holdingsCloseConfirmation, isPresented: Binding(
            get: { closingPosition != nil }, set: { if !$0 { closingPosition = nil } }
        ), titleVisibility: .visible) {
            if let position = closingPosition {
                Button(L10n.holdingsClosePosition, role: .destructive) {
                    Task { await viewModel.deleteHolding(accountId: position.accountId, isin: position.isin) }
                }
            }
        }
    }

    private func holdingRow(_ detail: HoldingDetail) -> some View {
        NavigationLink {
            HoldingDetailView(accountId: detail.accountId, isin: detail.isin, privacyMode: privacyMode)
        } label: { iOSHoldingRow(detail: detail, privacyMode: privacyMode) }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !viewModel.demoMode.isDemoModeEnabled {
                Button(role: .destructive) { closingPosition = HoldingEditItem(accountId: detail.accountId, isin: detail.isin) } label: {
                    Label(L10n.holdingsClosePosition, systemImage: "archivebox")
                }
            }
        }
    }

    private func resetFilters() {
        selectedAccountId = -1; filterMode = .all; sortMode = .valueDescending
        searchText = ""; groupByAccount = false
    }
}

struct iOSHoldingRow: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dynamicTypeSize) private var typeSize
    let detail: HoldingDetail
    let privacyMode: Bool

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            VStack(alignment: .leading, spacing: 5) {
                Text(detail.instrumentName).font(.body.weight(.semibold)).foregroundStyle(.primary).lineLimit(2)
                Text(viewModel.bankAccounts.first { $0.id == detail.accountId }?.displayName ?? detail.isin)
                    .font(.caption).foregroundStyle(.secondary)
                if detail.currentValueEUR == nil {
                    Label(L10n.designQuoteUnavailable, systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 5) {
                Text(privacyMode ? L10n.privacyHiddenLong : detail.currentValueEUR.map { formatCurrency($0, currency: "EUR") } ?? L10n.generalNA)
                    .font(AppTheme.Typography.rowValue).foregroundStyle(.primary)
                if !privacyMode, let change = viewModel.cachedPositionTWR[detail.id] {
                    ChangeLabel(change: change).font(.caption)
                }
            }.fixedSize(horizontal: !typeSize.isAccessibilitySize, vertical: false)
        }
        .padding(.vertical, 6).frame(minHeight: 60)
        .accessibilityElement(children: .combine)
    }
}

struct iOSClosedPositionsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var positions: [HoldingEditItem] = []
    var body: some View {
        List {
            ForEach(positions) { position in
                NavigationLink {
                    HoldingDetailView(accountId: position.accountId, isin: position.isin)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.instruments.first { $0.isin == position.isin }?.displayName ?? position.isin)
                        Text(viewModel.bankAccounts.first { $0.id == position.accountId }?.displayName ?? "")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if positions.isEmpty { ContentUnavailableView(L10n.designNoClosedPositions, systemImage: "archivebox") }
        }
        .navigationTitle(L10n.designClosedPositions)
        .task {
            let transactions = await viewModel.db.getAllHoldingTransactions()
            let live = Set(viewModel.holdings.map { HoldingEditItem(accountId: $0.accountId, isin: $0.isin).id })
            var seen = Set<String>()
            positions = transactions.compactMap { transaction in
                let position = HoldingEditItem(accountId: transaction.accountId, isin: transaction.isin)
                return !live.contains(position.id) && seen.insert(position.id).inserted ? position : nil
            }.sorted { $0.isin < $1.isin }
        }
    }
}
