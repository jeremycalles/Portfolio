import SwiftUI

// MARK: - Icon-Based View Mode Selector
struct IconViewModeSelector: View {
    @Binding var selectedMode: iOSDashboardViewMode
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(iOSDashboardViewMode.allCases) { mode in
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedMode = mode
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedMode == mode ? mode.icon + ".fill" : mode.icon)
                            .font(.system(size: 14, weight: .medium))
                        Text(mode.displayName)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(selectedMode == mode ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background {
                        if selectedMode == mode {
                            Capsule()
                                .fill(Color.blue)
                                .matchedGeometryEffect(id: "viewModeSelector", in: animation)
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
