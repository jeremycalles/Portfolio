import SwiftUI
import Charts

// MARK: - Enhanced Dashboard Holdings Section (with EnhancedTrendCard)
struct iOSDashboardHoldingsSectionEnhanced: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
            if viewModel.cachedHoldingsWithQuantity.isEmpty {
                Text(L10n.holdingsNoHoldings)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(viewModel.cachedHoldingsWithQuantity, id: \.isin) { holding in
                    let history = viewModel.cachedHoldingHistories[holding.isin] ?? []
                    let valueEUR = history.last?.value
                    
                    EnhancedTrendCard(
                        title: holding.name,
                        history: history,
                        currentValue: valueEUR,
                        privacyMode: privacyMode,
                        performancePercent: viewModel.cachedHoldingTWR[holding.isin]
                    )
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Previews

#Preview("DashboardHoldingsSection") {
    iOSDashboardHoldingsSectionEnhanced(privacyMode: false)
        .environmentObject(AppViewModel.preview)
}
