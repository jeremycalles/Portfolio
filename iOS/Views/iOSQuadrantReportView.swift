import SwiftUI

struct iOSQuadrantReportView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dynamicTypeSize) private var typeSize
    let privacyMode: Bool
    @State private var byAccount = false

    private var groups: [AllocationGroup] {
        if byAccount {
            return viewModel.bankAccounts.map { account in
                AllocationGroup(id: "account-\(account.id)", name: account.displayName,
                    holdings: viewModel.cachedHoldingDetailsByAccount[account.id] ?? [])
            }.filter { !$0.holdings.isEmpty }.sorted { $0.value > $1.value }
        }
        let details = viewModel.cachedHoldingDetailsByAccount.values.flatMap { $0 }
        var groups = viewModel.quadrants.map { quadrant in
            let isins = Set(viewModel.instruments.filter { $0.quadrantId == quadrant.id }.map(\.isin))
            return AllocationGroup(id: "category-\(quadrant.id)", name: quadrant.name,
                holdings: details.filter { isins.contains($0.isin) })
        }
        let unassigned = Set(viewModel.instruments.filter { $0.quadrantId == nil }.map(\.isin))
        groups.append(AllocationGroup(id: "unassigned", name: L10n.designUnassignedCategory, holdings: details.filter { unassigned.contains($0.isin) }))
        return groups.filter { !$0.holdings.isEmpty }.sorted { $0.value > $1.value }
    }

    var body: some View {
        List {
            Section {
                Picker(L10n.designAllocation, selection: $byAccount) {
                    Text(L10n.designCategories).tag(false)
                    Text(L10n.navAccounts).tag(true)
                }.pickerStyle(.segmented)
            }
            if groups.isEmpty {
                ContentUnavailableView(L10n.designNoAllocation, systemImage: "chart.pie")
            }
            let total = groups.reduce(0) { $0 + $1.value }
            Section {
                ForEach(groups) { group in
                    NavigationLink {
                        List {
                            ForEach(group.holdings.sorted { ($0.currentValueEUR ?? 0) > ($1.currentValueEUR ?? 0) }) { holding in
                                NavigationLink {
                                    HoldingDetailView(accountId: holding.accountId, isin: holding.isin, privacyMode: privacyMode)
                                } label: { iOSHoldingRow(detail: holding, privacyMode: privacyMode) }
                            }
                        }.navigationTitle(group.name)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
                            layout {
                                Text(group.name).font(.headline)
                                if !typeSize.isAccessibilitySize { Spacer() }
                                Text(privacyMode ? L10n.privacyHiddenLong : total > 0 ? formatPercent(group.value / total * 100, fractionDigits: 1) : L10n.generalNA)
                                    .monospacedDigit()
                            }
                            if !privacyMode {
                                ProgressView(value: total > 0 ? group.value / total : 0)
                                    .tint(AppTheme.portfolio).accessibilityHidden(true)
                                Text(formatCurrency(group.value, currency: "EUR")).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 8).accessibilityElement(children: .combine)
                    }
                }
            } footer: {
                if groups.contains(where: { $0.holdings.contains(where: { $0.currentValueEUR == nil }) }) {
                    Text(L10n.designUnavailablePrices)
                }
            }
            Section {
                NavigationLink(L10n.designManageAccounts) { iOSAccountsManagementView() }
                NavigationLink(L10n.designManageCategories) { iOSCategoriesManagementView() }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.startRefreshTask(showCompletionDelay: false).value }
    }
}

private struct AllocationGroup: Identifiable {
    let id: String
    let name: String
    let holdings: [HoldingDetail]
    var value: Double { holdings.compactMap(\.currentValueEUR).reduce(0, +) }
}

struct iOSAccountsManagementView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @AppStorage("privacyMode") private var privacyMode = false
    @State private var showingAdd = false
    @State private var deletingAccount: BankAccount?
    var body: some View {
        List {
            ForEach(viewModel.bankAccounts) { account in
                NavigationLink {
                    iOSAllHoldingsView(privacyMode: privacyMode, accountId: account.id).navigationTitle(account.displayName)
                } label: { Text(account.displayName) }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) { deletingAccount = account } label: { Label(L10n.generalDelete, systemImage: "trash") }
                        .disabled(viewModel.demoMode.isDemoModeEnabled)
                }
            }
            Button { showingAdd = true } label: { Label(L10n.accountsAddAccount, systemImage: "plus") }
                .disabled(viewModel.demoMode.isDemoModeEnabled)
        }
        .navigationTitle(L10n.designManageAccounts)
        .sheet(isPresented: $showingAdd) { AddBankAccountSheet() }
        .confirmationDialog(L10n.designDeleteAccountWarning, isPresented: Binding(get: { deletingAccount != nil }, set: { if !$0 { deletingAccount = nil } }), titleVisibility: .visible) {
            if let account = deletingAccount {
                Button(L10n.generalDelete, role: .destructive) { Task { await viewModel.deleteBankAccount(id: account.id) } }
            }
        }
    }
}

struct iOSCategoriesManagementView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showingAdd = false
    var body: some View {
        List {
            ForEach(viewModel.quadrants) { quadrant in Text(quadrant.name) }
                .onDelete { indices in
                    let ids = indices.map { viewModel.quadrants[$0].id }
                    Task { for id in ids { await viewModel.deleteQuadrant(id: id) }; await viewModel.recomputeDashboardCache() }
                }
                .deleteDisabled(viewModel.demoMode.isDemoModeEnabled)
            Button { showingAdd = true } label: { Label(L10n.quadrantsAddQuadrant, systemImage: "plus") }
                .disabled(viewModel.demoMode.isDemoModeEnabled)
        }.navigationTitle(L10n.designManageCategories)
            .sheet(isPresented: $showingAdd) { AddQuadrantSheet() }
    }
}
