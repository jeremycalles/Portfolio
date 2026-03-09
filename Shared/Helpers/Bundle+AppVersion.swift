import Foundation

extension Bundle {
    /// App version string from Info.plist (MARKETING_VERSION). Same source as Xcode project.
    static var appShortVersion: String {
        main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// Build number from Info.plist (CURRENT_PROJECT_VERSION).
    static var appBuildNumber: String {
        main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
