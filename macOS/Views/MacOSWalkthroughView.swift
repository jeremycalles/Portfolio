#if os(macOS)
import SwiftUI

private struct MacOSWalkthroughPage: Identifiable {
    let id: Int
    let symbolName: String
    let title: String
    let message: String
}

struct MacOSWalkthroughView: View {
    let onFinish: () -> Void

    @State private var selectedPage = 0
    @State private var neverShowAgain = true

    private var pages: [MacOSWalkthroughPage] {
        [
            MacOSWalkthroughPage(
                id: 0,
                symbolName: "chart.pie.fill",
                title: L10n.walkthroughPageDashboardTitle,
                message: L10n.walkthroughPageDashboardMessage
            ),
            MacOSWalkthroughPage(
                id: 1,
                symbolName: "building.columns.fill",
                title: L10n.walkthroughPageBankAccountTitle,
                message: L10n.walkthroughPageBankAccountMessage
            ),
            MacOSWalkthroughPage(
                id: 2,
                symbolName: "square.grid.2x2.fill",
                title: L10n.walkthroughPageQuadrantsTitle,
                message: L10n.walkthroughPageQuadrantsMessage
            ),
            MacOSWalkthroughPage(
                id: 3,
                symbolName: "doc.text.magnifyingglass",
                title: L10n.walkthroughPageInstrumentsTitle,
                message: L10n.walkthroughPageInstrumentsMessage
            ),
            MacOSWalkthroughPage(
                id: 4,
                symbolName: "list.bullet.rectangle.fill",
                title: L10n.walkthroughPageHoldingsTitle,
                message: L10n.walkthroughPageHoldingsMessage
            ),
            MacOSWalkthroughPage(
                id: 5,
                symbolName: "arrow.triangle.2.circlepath",
                title: L10n.walkthroughPageRefreshTitle,
                message: L10n.walkthroughPageRefreshMessage
            ),
            MacOSWalkthroughPage(
                id: 6,
                symbolName: "lock.shield.fill",
                title: L10n.walkthroughPagePrivacyTitle,
                message: L10n.walkthroughPagePrivacyMessage
            )
        ]
    }

    private var currentPage: MacOSWalkthroughPage {
        pages[selectedPage]
    }

    private var isLastPage: Bool {
        selectedPage == pages.count - 1
    }

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                header

                HStack(spacing: 18) {
                    stepList

                    pageDetail
                }

                footer
            }
            .padding(24)
        }
        .frame(width: 760, height: 560)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.walkthroughTitle)
                    .font(.largeTitle.bold())

                Text(L10n.appTagline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            MacOSWalkthroughGlassButton(
                title: L10n.walkthroughSkip,
                isCompact: true,
                action: finish
            )
        }
    }

    private var stepList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(pages) { page in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedPage = page.id
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: page.symbolName)
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 22)
                            .foregroundStyle(selectedPage == page.id ? Color.accentColor : .secondary)

                        Text(page.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .background {
                    if selectedPage == page.id {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.accentColor.opacity(0.12))
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 260)
        .macOSWalkthroughLiquidGlass(cornerRadius: 28, interactive: true)
    }

    private var pageDetail: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            Image(systemName: currentPage.symbolName)
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 116, height: 116)
                .macOSWalkthroughLiquidGlass(cornerRadius: 58, interactive: true)

            VStack(spacing: 12) {
                Text(currentPage.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(currentPage.message)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 360)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 28)
            .macOSWalkthroughLiquidGlass(cornerRadius: 30)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Toggle(isOn: $neverShowAgain) {
                Text(L10n.walkthroughDoNotShowAgain)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .toggleStyle(.checkbox)

            Spacer()

            if selectedPage > 0 {
                MacOSWalkthroughGlassButton(title: L10n.walkthroughBack) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedPage = max(selectedPage - 1, 0)
                    }
                }
            }

            MacOSWalkthroughGlassButton(title: isLastPage ? L10n.walkthroughStartUsingApp : L10n.walkthroughNext, isProminent: true) {
                if isLastPage {
                    finish()
                } else {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedPage = min(selectedPage + 1, pages.count - 1)
                    }
                }
            }
        }
        .padding(16)
        .macOSWalkthroughLiquidGlass(cornerRadius: 28, interactive: true)
    }

    private func finish() {
        if neverShowAgain {
            UserDefaults.standard.set(true, forKey: macOSWalkthroughStorageKey)
        }
        onFinish()
    }
}

private struct MacOSWalkthroughGlassButton: View {
    let title: String
    var isProminent = false
    var isCompact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(isCompact ? .headline : .headline.weight(.semibold))
                .foregroundStyle(isProminent ? Color.accentColor : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, isCompact ? 22 : 24)
                .padding(.vertical, isCompact ? 12 : 13)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .macOSWalkthroughLiquidGlass(cornerRadius: isCompact ? 24 : 26, interactive: true)
    }
}

private struct MacOSWalkthroughLiquidGlassModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let cornerRadius: CGFloat
    let interactive: Bool

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            if interactive {
                content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.28), lineWidth: 1)
                }
        }
    }
}

private extension View {
    func macOSWalkthroughLiquidGlass(cornerRadius: CGFloat, interactive: Bool = false) -> some View {
        modifier(MacOSWalkthroughLiquidGlassModifier(cornerRadius: cornerRadius, interactive: interactive))
    }
}

#Preview("MacOSWalkthroughView") {
    MacOSWalkthroughView(onFinish: { })
        .environmentObject(LanguageManager.shared)
}
#endif
