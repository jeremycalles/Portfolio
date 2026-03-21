import SwiftUI
import Charts

// MARK: - Enhanced Dashboard Holdings Section (with EnhancedTrendCard)
struct iOSDashboardHoldingsSectionEnhanced: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    @State private var holdingsWithQuantity: [(isin: String, name: String, quantity: Double)] = []
    @State private var holdingHistories: [String: [(date: Date, value: Double)]] = [:]
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
            if holdingsWithQuantity.isEmpty {
                Text(L10n.holdingsNoHoldings)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(holdingsWithQuantity, id: \.isin) { holding in
                    let history = holdingHistories[holding.isin] ?? []
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
        .task(id: viewModel.selectedPeriod) {
            holdingsWithQuantity = await viewModel.getAllHoldingsWithQuantity()
            holdingHistories = [:]
            for h in holdingsWithQuantity {
                holdingHistories[h.isin] = await viewModel.getHoldingValueHistory(isin: h.isin, quantity: h.quantity)
            }
        }
    }
}
