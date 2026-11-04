#if os(iOS)
import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass
import LocalAuthentication

private let iosBiometricProtectionEnabledKey = "ios_biometric_protection_enabled"

// MARK: - iOS Lock Manager
@MainActor
final class IOSLockManager: ObservableObject {
    static let shared = IOSLockManager()

    @Published private(set) var isUnlocked = false
    @Published var unlockErrorMessage: String?

    @Published var isTouchIDProtectionEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isTouchIDProtectionEnabled, forKey: iosBiometricProtectionEnabledKey)
            if isTouchIDProtectionEnabled {
                lock()
            } else {
                isUnlocked = true
                stopInactivityTimer()
            }
        }
    }

    private var lastActivityDate = Date()
    private let inactivityInterval: TimeInterval = 300
    private var inactivityTimer: Timer?

    private init() {
        self.isTouchIDProtectionEnabled = UserDefaults.standard.object(forKey: iosBiometricProtectionEnabledKey) as? Bool ?? false
    }

    func unlock(reason: String) async {
        unlockErrorMessage = nil
        do {
            let success = try await BiometricAuth.evaluate(localizedReason: reason)
            if success {
                isUnlocked = true
                recordActivity()
                startInactivityTimer()
            }
        } catch {
            unlockErrorMessage = error.localizedDescription
        }
    }

    func lock() {
        isUnlocked = false
        stopInactivityTimer()
    }

    func recordActivity() {
        lastActivityDate = Date()
    }

    private func startInactivityTimer() {
        stopInactivityTimer()
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkInactivity()
            }
        }
        inactivityTimer?.tolerance = 10
        RunLoop.main.add(inactivityTimer!, forMode: .common)
    }

    private func checkInactivity() {
        guard isUnlocked else { return }
        if Date().timeIntervalSince(lastActivityDate) >= inactivityInterval {
            lock()
        }
    }

    private func stopInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }
}

// MARK: - Lock Screen View
private enum IOSUnlockMethod {
    case faceID, touchID, device

    static var available: IOSUnlockMethod {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return .device }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        default: return .device
        }
    }

    var title: String {
        switch self {
        case .faceID: return L10n.lockFaceID
        case .touchID: return L10n.lockUnlockButton
        case .device: return L10n.lockActionUnlock
        }
    }

    var symbol: String {
        switch self {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .device: return "lock.open"
        }
    }
}

struct IOSLockScreenView: View {
    @ObservedObject var lockManager: IOSLockManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var isAuthenticating = false
    @State private var unlockMethod: IOSUnlockMethod = .device

    var body: some View {
        IOSLockScreenContent(
            unlockMethod: unlockMethod,
            isAuthenticating: isAuthenticating,
            errorMessage: lockManager.unlockErrorMessage,
            onUnlock: unlock
        )
        .onAppear { unlockMethod = .available }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { unlockMethod = .available }
        }
    }

    private func unlock() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        Task {
            await lockManager.unlock(reason: L10n.lockReason)
            isAuthenticating = false
        }
    }
}

/// The same branding remains visible behind the system authentication prompt
/// and in the app switcher. This view never reads portfolio data.
private struct IOSLockScreenContent: View {
    var unlockMethod: IOSUnlockMethod = .device
    var isAuthenticating = false
    var errorMessage: String?
    var onUnlock: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 20)
                    VStack(spacing: 20) {
                        Image("PortfolioLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 104, height: 104)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
                            .accessibilityHidden(true)
                        Text(L10n.appName)
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        Text(L10n.designWelcomeTitle)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    VStack(spacing: 16) {
                        Label(L10n.lockPortfolioLocked, systemImage: "lock.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button(action: { onUnlock?() }) {
                            HStack(spacing: 10) {
                                if isAuthenticating { ProgressView().tint(AppTheme.onSelection) }
                                else { Image(systemName: unlockMethod.symbol).accessibilityHidden(true) }
                                Text(isAuthenticating ? L10n.lockAuthenticating : unlockMethod.title)
                                    .multilineTextAlignment(.center)
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 28)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .foregroundStyle(AppTheme.onSelection)
                            .background(AppTheme.selection, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(isAuthenticating || onUnlock == nil)
                        .opacity(onUnlock == nil ? 0 : 1)
                        .accessibilityHidden(onUnlock == nil)
                        .accessibilityLabel(isAuthenticating ? L10n.lockAuthenticating : unlockMethod.title)
                        .accessibilityHint(L10n.lockReason)
                        if onUnlock != nil, let errorMessage {
                            Text(errorMessage)
                                .font(.callout)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }
                    }
                    Spacer(minLength: 20)
                    Text(L10n.lockPrivacyReassurance)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: typeSize.isAccessibilitySize ? 440 : 360)
                .padding(.horizontal, 28)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color(.systemBackground).ignoresSafeArea())
        }
    }
}

// MARK: - Touch Activity
/// Reports every touch in the window without taking part in gesture handling.
/// A SwiftUI gesture on the root view stops List rows from receiving taps.
private final class TouchActivityRecognizer: UIGestureRecognizer {
    var onTouch: (() -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        onTouch?()
        state = .failed
    }
}

private final class TouchActivityMonitorView: UIView {
    private let recognizer = TouchActivityRecognizer()

    var onTouch: (() -> Void)? {
        didSet { recognizer.onTouch = onTouch }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        recognizer.view?.removeGestureRecognizer(recognizer)
        window?.addGestureRecognizer(recognizer)
    }
}

private struct TouchActivityMonitor: UIViewRepresentable {
    let onTouch: () -> Void

    func makeUIView(context: Context) -> TouchActivityMonitorView {
        let view = TouchActivityMonitorView()
        view.onTouch = onTouch
        return view
    }

    func updateUIView(_ uiView: TouchActivityMonitorView, context: Context) {
        uiView.onTouch = onTouch
    }
}

// MARK: - Gate View
struct IOSLockGateView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var lockManager: IOSLockManager

    var body: some View {
        Group {
            if !lockManager.isTouchIDProtectionEnabled || lockManager.isUnlocked {
                iOSRootView()
                    .background(TouchActivityMonitor { lockManager.recordActivity() })
            } else {
                IOSLockScreenView(lockManager: lockManager)
            }
        }
        .overlay {
            if scenePhase != .active && lockManager.isTouchIDProtectionEnabled {
                IOSLockScreenContent()
                    .accessibilityHidden(true)
            }
        }
    }
}
#endif

// MARK: - Previews

#Preview("IOSLockGateView") {
    IOSLockGateView()
        .environmentObject(AppViewModel.preview)
        .environmentObject(IOSLockManager.shared)
}

#Preview("Unlock — Face ID") {
    IOSLockScreenContent(unlockMethod: .faceID, onUnlock: {})
}

#Preview("Unlock — Dark") {
    IOSLockScreenContent(unlockMethod: .faceID, onUnlock: {})
        .preferredColorScheme(.dark)
}

#Preview("Unlock — Large text") {
    IOSLockScreenContent(unlockMethod: .faceID, onUnlock: {})
        .environment(\.dynamicTypeSize, .accessibility3)
}
