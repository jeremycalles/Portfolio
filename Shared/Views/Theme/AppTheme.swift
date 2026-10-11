import SwiftUI

enum AppTheme {
    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
    }

    enum Radius {
        static let chip: CGFloat = 8
        static let control: CGFloat = 10
        static let card: CGFloat = 18
        static let hero: CGFloat = 24
    }

    /// Text styles built on Dynamic Type. Amounts use monospaced digits so columns line up.
    enum Typography {
        static let hero = Font.system(.largeTitle, design: .rounded).weight(.bold).monospacedDigit()
        static let value = Font.title3.weight(.semibold).monospacedDigit()
        static let rowValue = Font.body.weight(.semibold).monospacedDigit()
        static let sectionTitle = Font.headline
        static let control = Font.subheadline.weight(.semibold)
        static let label = Font.caption
        static let caption = Font.caption2
    }

    // Blue/amber remain distinguishable for common red-green color deficiencies.
    static let gain = Color.blue
    static let loss = Color.orange
    static let neutral = Color.secondary
    static let portfolio = Color.indigo
    static let investedCapital = Color.secondary
    static let sp500 = Color.orange
    static let gold = Color(red: 0.72, green: 0.48, blue: 0.05)
    static let msciWorld = Color.cyan

    /// Selected state for pills and segmented controls. Neutral on purpose:
    /// blue and orange already mean gain and loss.
    /// Concrete colors, not `.primary`: on glass `.primary` picks up vibrancy and
    /// turned the selected pill pale grey behind white text.
    #if os(iOS)
    static let selection = Color(uiColor: .label)
    static let onSelection = Color(uiColor: .systemBackground)
    #else
    static let selection = Color(nsColor: .labelColor)
    static let onSelection = Color(nsColor: .windowBackgroundColor)
    #endif

    /// Allocation colors (quadrants, accounts). No blue or orange, so a slice is never
    /// read as a gain or a loss. Picked by stable id so a quadrant keeps its color
    /// when its rank changes.
    static let allocationPalette: [Color] = [.purple, .teal, .yellow, .pink, .mint, .indigo, .brown, .gray]

    static func allocationColor(id: Int?) -> Color {
        guard let id else { return .gray }
        return allocationPalette[abs(id) % allocationPalette.count]
    }

    static func changeColor(_ change: Double) -> Color {
        change >= 0 ? gain : loss
    }
}

struct PortfolioCardModifier: ViewModifier {
    var padding: CGFloat = AppTheme.Spacing.large

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }
}

extension View {
    func portfolioCard(padding: CGFloat = AppTheme.Spacing.large) -> some View {
        modifier(PortfolioCardModifier(padding: padding))
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    var systemImage: String? = nil
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            HStack {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(tint)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .portfolioCard(padding: AppTheme.Spacing.medium)
        .accessibilityElement(children: .combine)
    }
}

struct PortfolioEmptyStateView: View {
    let title: String
    var message: String? = nil
    var systemImage = "tray"

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let message { Text(message) }
        }
    }
}

/// Lays children out left to right and wraps whole children onto the next line.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
