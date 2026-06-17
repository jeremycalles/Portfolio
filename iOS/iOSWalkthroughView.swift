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
                symbolName: "doc.text.magnifyingglass",
                title: L10n.walkthroughPageInstrumentsTitle,
                message: L10n.walkthroughPageInstrumentsMessage
            ),
            WalkthroughPage(
                id: 2,
                symbolName: "list.bullet.rectangle.fill",
                title: L10n.walkthroughPageHoldingsTitle,
                message: L10n.walkthroughPageHoldingsMessage
            ),
            WalkthroughPage(
                id: 3,
                symbolName: "arrow.triangle.2.circlepath",
                title: L10n.walkthroughPageRefreshTitle,
                message: L10n.walkthroughPageRefreshMessage
            ),
            WalkthroughPage(
                id: 4,
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
        NavigationStack {
            VStack(spacing: 0) {
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

                    Button {
                        finish()
                    } label: {
                        Text(isLastPage ? L10n.walkthroughStartUsingApp : L10n.walkthroughSkip)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if !isLastPage {
                        Button {
                            withAnimation(.easeInOut) {
                                selectedPage = min(selectedPage + 1, pages.count - 1)
                            }
                        } label: {
                            Text(L10n.walkthroughNext)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .padding(24)
                .background(.regularMaterial)
            }
            .navigationTitle(L10n.walkthroughTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.walkthroughSkip) {
                        finish()
                    }
                }
            }
        }
    }

    private func finish() {
        if neverShowAgain {
            UserDefaults.standard.set(true, forKey: iOSWalkthroughStorageKey)
        }
        onFinish()
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
                    .background(
                        Circle()
                            .fill(Color.accentColor.opacity(0.12))
                    )

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
