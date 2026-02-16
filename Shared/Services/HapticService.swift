import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Haptic Service
/// Cross-platform haptic feedback abstraction
enum HapticService {
    enum FeedbackStyle {
        case light
        case medium
        case heavy
        case success
        case warning
        case error
    }
    
    /// Triggers haptic feedback
    /// - Parameter style: The style of haptic feedback to produce
    static func impact(_ style: FeedbackStyle = .light) {
        #if os(iOS)
        switch style {
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        case .medium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        case .heavy:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
        #else
        // macOS: Haptic feedback not available via standard API
        // Could potentially use NSHapticFeedbackManager for Force Touch trackpads
        // For now, no-op on macOS
        #endif
    }
    
    /// Triggers a selection change haptic
    static func selectionChanged() {
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #endif
    }
}
