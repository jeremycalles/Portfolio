import SwiftUI
import Charts

// MARK: - Enhanced Dashboard Quadrants Section (with EnhancedTrendCard)
struct iOSDashboardQuadrantsSectionEnhanced: View {
    @EnvironmentObject var viewModel: AppViewModel
    let privacyMode: Bool
    @State private var quadrantGoldMode: Set<Int> = []
    @State private var unassignedGoldMode: Bool = false
    @State private var quadrantHistories: [Int: [(date: Date, value: Double)]] = [:]
    @State private var goldQuadrantHistories: [Int: [(date: Date, value: Double)]] = [:]
    @State private var unassignedHistory: [(date: Date, value: Double)] = []
    @State private var unassignedGoldHistory: [(date: Date, value: Double)] = []
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
            ForEach(viewModel.quadrants) { quadrant in
                let isGoldMode = quadrantGoldMode.contains(quadrant.id)
                let history = isGoldMode ? (goldQuadrantHistories[quadrant.id] ?? []) : (quadrantHistories[quadrant.id] ?? [])
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
            
            let unassigned = unassignedGoldMode ? unassignedGoldHistory : unassignedHistory
            if !unassigned.isEmpty {
                let title = unassignedGoldMode ? "Unassigned (oz Au)" : "Unassigned"
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
        .task(id: viewModel.selectedPeriod) {
            for q in viewModel.quadrants {
                quadrantHistories[q.id] = await viewModel.getQuadrantValueHistory(quadrantId: q.id)
                goldQuadrantHistories[q.id] = await viewModel.getQuadrantValueHistoryInGold(quadrantId: q.id)
            }
            unassignedHistory = await viewModel.getQuadrantValueHistory(quadrantId: nil)
            unassignedGoldHistory = await viewModel.getQuadrantValueHistoryInGold(quadrantId: nil)
        }
    }
}
