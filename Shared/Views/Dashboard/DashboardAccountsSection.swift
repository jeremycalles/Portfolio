import SwiftUI
import Charts

// MARK: - Enhanced Dashboard Accounts Section (with EnhancedTrendCard)
struct iOSDashboardAccountsSectionEnhanced: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    @State private var accountHistories: [Int: [(date: Date, value: Double)]] = [:]
    @State private var accountDetails: [Int: [HoldingDetail]] = [:]
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
            if viewModel.bankAccounts.isEmpty {
                Text(L10n.accountsNoAccounts)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(viewModel.bankAccounts) { account in
                    let history = accountHistories[account.id] ?? []
                    let details = accountDetails[account.id] ?? []
                    let totalValue = details.compactMap { $0.currentValueEUR }.reduce(0, +)
                    
                    EnhancedTrendCard(
                        title: "\(account.displayName) (\(details.count) holdings)",
                        history: history,
                        currentValue: totalValue,
                        privacyMode: privacyMode
                    )
                }
            }
        }
        .padding(.horizontal)
        .task(id: viewModel.selectedPeriod) {
            for account in viewModel.bankAccounts {
                accountHistories[account.id] = await viewModel.getAccountValueHistory(accountId: account.id)
                accountDetails[account.id] = await viewModel.getHoldingDetails(forAccount: account.id)
            }
        }
    }
}
