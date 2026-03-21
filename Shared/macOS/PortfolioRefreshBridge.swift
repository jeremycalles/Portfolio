#if os(macOS)
import Foundation

/// Shared between the main Mac app and the embedded Refresh Login Item (Mac App Store / sandbox).
enum PortfolioRefreshBridge {
    /// Register the same App Group ID in Apple Developer for the macOS app and the login item target.
    static let appGroupIdentifier = "group.com.portfolio.app"

    /// Must match `PRODUCT_BUNDLE_IDENTIFIER` of the Refresh Login Item target and `SMAppService.loginItem(identifier:)`.
    static let loginItemBundleIdentifier = "com.portfolio.app.ios.RefreshLoginItem"

    static let refreshURL = URL(string: "portfolio://refresh")!

    static let refreshIntervalSecondsKey = "refreshIntervalSeconds"
    static let backgroundRefreshEnabledKey = "backgroundRefreshEnabled"

    /// Darwin notify name so the helper can reschedule when the main app updates the shared defaults.
    static let refreshPrefsDarwinNotification = "com.portfolio.app.refreshPrefsChanged" as CFString

    static var defaultRefreshIntervalSeconds: Int { 10_800 }
}

#endif
