import SwiftUI

// MARK: - Change Label (Shared)
struct ChangeLabel: View {
    let change: Double
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)
            Text(String(format: "%.2f%%", abs(change)))
                .font(.caption)
        }
        .foregroundColor(change >= 0 ? .green : .red)
    }
}

// MARK: - Previews

#Preview("ChangeLabel Positive") {
    ChangeLabel(change: 7.63)
        .padding()
}

#Preview("ChangeLabel Negative") {
    ChangeLabel(change: -3.21)
        .padding()
}
