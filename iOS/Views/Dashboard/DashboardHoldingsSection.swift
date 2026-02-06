import SwiftUI
import Charts

// MARK: - Enhanced Dashboard Holdings Section (with EnhancedTrendCard)
struct iOSDashboardHoldingsSectionEnhanced: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
            let allHoldings = viewModel.getAllHoldingsWithQuantity()
            
            if allHoldings.isEmpty {
                Text(L10n.holdingsNoHoldings)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(allHoldings, id: \.isin) { holding in
                    let history = viewModel.getHoldingValueHistory(isin: holding.isin, quantity: holding.quantity)
                    let valueEUR = history.last?.value
                    
                    EnhancedTrendCard(
                        title: holding.name,
                        history: history,
                        currentValue: valueEUR,
                        privacyMode: privacyMode
                    )
                }
            }
        }
        .padding(.horizontal)
    }
}
