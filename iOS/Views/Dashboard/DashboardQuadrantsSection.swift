import SwiftUI
import Charts

// MARK: - Enhanced Dashboard Quadrants Section (with EnhancedTrendCard)
struct iOSDashboardQuadrantsSectionEnhanced: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    @State private var quadrantGoldMode: Set<Int> = []  // Track which quadrants show gold ounces
    @State private var unassignedGoldMode: Bool = false
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
            // Quadrant Charts
            ForEach(viewModel.quadrants) { quadrant in
                let isGoldMode = quadrantGoldMode.contains(quadrant.id)
                let history = isGoldMode
                    ? viewModel.getQuadrantValueHistoryInGold(quadrantId: quadrant.id)
                    : viewModel.getQuadrantValueHistory(quadrantId: quadrant.id)
                let currentValue = history.last?.value
                let title = isGoldMode ? "\(quadrant.name) (oz Au)" : quadrant.name
                
                EnhancedTrendCard(
                    title: title,
                    history: history,
                    currentValue: currentValue,
                    privacyMode: privacyMode,
                    unit: isGoldMode ? "oz" : "EUR"
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        let id = quadrant.id
                        if quadrantGoldMode.contains(id) {
                            quadrantGoldMode.remove(id)
                        } else {
                            quadrantGoldMode.insert(id)
                        }
                    }
                }
            }
            
            // Unassigned holdings
            let unassignedHistory = unassignedGoldMode
                ? viewModel.getQuadrantValueHistoryInGold(quadrantId: nil)
                : viewModel.getQuadrantValueHistory(quadrantId: nil)
            if !unassignedHistory.isEmpty || !viewModel.getQuadrantValueHistory(quadrantId: nil).isEmpty {
                let title = unassignedGoldMode ? "Unassigned (oz Au)" : "Unassigned"
                EnhancedTrendCard(
                    title: title,
                    history: unassignedHistory,
                    currentValue: unassignedHistory.last?.value,
                    privacyMode: privacyMode,
                    unit: unassignedGoldMode ? "oz" : "EUR"
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        unassignedGoldMode.toggle()
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}
