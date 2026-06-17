#if os(iOS)
import SwiftUI

private struct WalkthroughPage: Identifiable {
    let id: Int
    let symbolName: String
    let title: String
    let message: String
}

struct iOSWalkthroughView: View {
    let onFinish: () -> Void

    @State private var selectedPage = 0
    @State private var neverShowAgain = true

    private var pages: [WalkthroughPage] {
        [
            WalkthroughPage(
                id: 0,
                symbolName: "chart.pie.fill",
                title: L10n.walkthroughPageDashboardTitle,
                message: L10n.walkthroughPageDashboardMessage
            ),
            WalkthroughPage(
                id: 1,
                symbolName: "building.columns.fill",
                title: L10n.walkthroughPageBankAccountTitle,
                message: L10n.walkthroughPageBankAccountMessage
            ),
            WalkthroughPage(
                id: 2,
                symbolName: "square.grid.2x2.fill",
                title: L10n.walkthroughPageQuadrantsTitle,
                message: L10n.walkthroughPageQuadrantsMessage
            ),
            WalkthroughPage(
                id: 3,
                symbolName: "doc.text.magnifyingglass",
                title: L10n.walkthroughPageInstrumentsTitle,
                message: L10n.walkthroughPageInstrumentsMessage
            ),
            WalkthroughPage(
                id: 4,
                symbolName: "list.bullet.rectangle.fill",
                title: L10n.walkthroughPageHoldingsTitle,
                message: L10n.walkthroughPageHoldingsMessage
            ),
            WalkthroughPage(
                id: 5,
                symbolName: "arrow.triangle.2.circlepath",
                title: L10n.walkthroughPageRefreshTitle,
                message: L10n.walkthroughPageRefreshMessage
            ),
            WalkthroughPage(
                id: 6,
                symbolName: "lock.shield.fill",
                title: L10n.walkthroughPagePrivacyTitle,
                message: L10n.walkthroughPagePrivacyMessage
            )
        ]
    }

    private var isLastPage: Bool {
        selectedPage == pages.count - 1
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                TabView(selection: $selectedPage) {
                    ForEach(pages) { page in
                        WalkthroughPageView(page: page)
                            .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))

                VStack(spacing: 16) {
                    Toggle(isOn: $neverShowAgain) {
                        Text(L10n.walkthroughDoNotShowAgain)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .toggleStyle(.switch)

                    WalkthroughGlassButton(
                        title: isLastPage ? L10n.walkthroughStartUsingApp : L10n.walkthroughSkip,
                        isProminent: true,
                        action: finish
                    )

                    if !isLastPage {
                        WalkthroughGlassButton(title: L10n.walkthroughNext) {
                            withAnimation(.easeInOut) {
                                selectedPage = min(selectedPage + 1, pages.count - 1)
                            }
                        }
                    }
                }
                .padding(18)
                .walkthroughLiquidGlass(cornerRadius: 32, interactive: true)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }

    private var header: some View {
        HStack {
            Spacer()

            WalkthroughGlassButton(
                title: L10n.walkthroughSkip,
                isCompact: true,
                action: finish
            )
        }
        .overlay {
            Text(L10n.walkthroughTitle)
                .font(.title3.bold())
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private func finish() {
        if neverShowAgain {
            UserDefaults.standard.set(true, forKey: iOSWalkthroughStorageKey)
        }
        onFinish()
    }
}

private struct WalkthroughGlassButton: View {
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
                .frame(maxWidth: isCompact ? nil : .infinity)
                .padding(.horizontal, isCompact ? 24 : 18)
                .padding(.vertical, isCompact ? 14 : 18)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .walkthroughLiquidGlass(cornerRadius: isCompact ? 28 : 30, interactive: true)
    }
}

private struct WalkthroughLiquidGlassModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let cornerRadius: CGFloat
    let interactive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
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
                        .stroke(.white.opacity(0.34), lineWidth: 1)
                }
        }
    }
}

private extension View {
    func walkthroughLiquidGlass(cornerRadius: CGFloat, interactive: Bool = false) -> some View {
        modifier(WalkthroughLiquidGlassModifier(cornerRadius: cornerRadius, interactive: interactive))
    }
}

private struct WalkthroughPageView: View {
    let page: WalkthroughPage

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 36)

                Image(systemName: page.symbolName)
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 112, height: 112)
                    .walkthroughLiquidGlass(cornerRadius: 56, interactive: true)

                VStack(spacing: 12) {
                    Text(page.title)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text(page.message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .frame(maxWidth: 360)
                .padding(.horizontal, 22)
                .padding(.vertical, 24)
                .walkthroughLiquidGlass(cornerRadius: 30)

                Spacer(minLength: 36)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview("iOSWalkthroughView") {
    iOSWalkthroughView(onFinish: { })
        .environmentObject(LanguageManager.shared)
}
#endif
