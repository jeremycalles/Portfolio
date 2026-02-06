import SwiftUI

// MARK: - Modern Period Selector
struct ModernPeriodSelector: View {
    @Binding var selectedPeriod: ReportPeriod
    let accentColor: Color
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(ReportPeriod.allCases.filter { $0 != .oneDay }) { period in
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedPeriod = period
                    }
                } label: {
                    Text(period.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(selectedPeriod == period ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            if selectedPeriod == period {
                                Capsule()
                                    .fill(accentColor)
                                    .matchedGeometryEffect(id: "periodSelector", in: animation)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }
}
