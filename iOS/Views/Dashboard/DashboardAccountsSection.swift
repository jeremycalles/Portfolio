import SwiftUI
import Charts

// MARK: - Enhanced Dashboard Accounts Section (with EnhancedTrendCard)
struct iOSDashboardAccountsSectionEnhanced: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
            if viewModel.bankAccounts.isEmpty {
                Text(L10n.accountsNoAccounts)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                // Show accounts with data
                let accountsWithData = viewModel.bankAccounts.filter { account in
                    !viewModel.getAccountValueHistory(accountId: account.id).isEmpty
                }
                
                ForEach(accountsWithData) { account in
                    let history = viewModel.getAccountValueHistory(accountId: account.id)
                    let details = viewModel.getHoldingDetails(forAccount: account.id)
                    let totalValue = details.compactMap { $0.currentValueEUR }.reduce(0, +)
                    
                    EnhancedTrendCard(
                        title: "\(account.displayName) (\(details.count) holdings)",
                        history: history,
                        currentValue: totalValue,
                        privacyMode: privacyMode
                    )
                }
                
                // Accounts without chart data
                let accountsWithoutData = viewModel.bankAccounts.filter { account in
                    viewModel.getAccountValueHistory(accountId: account.id).isEmpty
                }
                
                ForEach(accountsWithoutData) { account in
                    let details = viewModel.getHoldingDetails(forAccount: account.id)
                    let totalValue = details.compactMap { $0.currentValueEUR }.reduce(0, +)
                    
                    EnhancedTrendCard(
                        title: "\(account.displayName) (\(details.count) holdings)",
                        history: [],
                        currentValue: totalValue,
                        privacyMode: privacyMode
                    )
                }
            }
        }
        .padding(.horizontal)
    }
}
