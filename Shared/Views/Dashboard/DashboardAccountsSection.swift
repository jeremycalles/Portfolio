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
                ForEach(viewModel.bankAccounts) { account in
                    let history = viewModel.cachedAccountHistories[account.id] ?? []
                    let details = viewModel.cachedHoldingDetailsByAccount[account.id] ?? []
                    let totalValue = details.compactMap { $0.currentValueEUR }.reduce(0, +)
                    
                    EnhancedTrendCard(
                        title: "\(account.displayName) (\(L10n.accountsHoldingsCount(details.count)))",
                        history: history,
                        currentValue: totalValue,
                        privacyMode: privacyMode,
                        performancePercent: viewModel.cachedAccountTWR[account.id]
                    )
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Previews

#Preview("DashboardAccountsSection") {
    iOSDashboardAccountsSectionEnhanced(privacyMode: false)
        .environmentObject(AppViewModel.preview)
}
