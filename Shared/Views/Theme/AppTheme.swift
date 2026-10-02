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
        static let control: CGFloat = 10
        static let card: CGFloat = 18
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
