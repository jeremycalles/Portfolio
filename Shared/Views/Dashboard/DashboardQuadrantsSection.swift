import SwiftUI
import Charts

// MARK: - Enhanced Dashboard Quadrants Section (with EnhancedTrendCard)
struct iOSDashboardQuadrantsSectionEnhanced: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    @State private var quadrantGoldMode: Set<Int> = []
    @State private var unassignedGoldMode: Bool = false
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
            ForEach(viewModel.quadrants) { quadrant in
                let isGoldMode = quadrantGoldMode.contains(quadrant.id)
                let history = isGoldMode
                    ? (viewModel.cachedGoldQuadrantHistories[quadrant.id] ?? [])
                    : (viewModel.cachedQuadrantHistories[quadrant.id] ?? [])
                let currentValue = history.last?.value
                let title = isGoldMode ? "\(quadrant.name) (oz Au)" : quadrant.name
                
                EnhancedTrendCard(
                    title: title,
                    history: history,
                    currentValue: currentValue,
                    privacyMode: privacyMode,
                    performancePercent: isGoldMode ? nil : viewModel.cachedQuadrantTWR[quadrant.id],
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
            
            let unassigned = unassignedGoldMode
                ? viewModel.cachedUnassignedGoldHistory
                : viewModel.cachedUnassignedHistory
            if !unassigned.isEmpty {
                let title = unassignedGoldMode ? "\(L10n.instrumentsUnassigned) (oz Au)" : L10n.instrumentsUnassigned
                EnhancedTrendCard(
                    title: title,
                    history: unassigned,
                    currentValue: unassigned.last?.value,
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

// MARK: - Previews

#Preview("DashboardQuadrantsSection") {
    iOSDashboardQuadrantsSectionEnhanced(privacyMode: false)
        .environmentObject(AppViewModel.preview)
}
