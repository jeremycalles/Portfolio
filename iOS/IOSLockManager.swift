#if os(iOS)
import SwiftUI
import UIKit

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
struct IOSLockScreenView: View {
    @ObservedObject var lockManager: IOSLockManager
    @State private var isAuthenticating = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)

                Text(L10n.lockReason)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)

                if let message = lockManager.unlockErrorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    isAuthenticating = true
                    lockManager.unlockErrorMessage = nil
                    Task {
                        await lockManager.unlock(reason: L10n.lockReason)
                        isAuthenticating = false
                    }
                } label: {
                    Label(L10n.lockUnlockButton, systemImage: "faceid")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAuthenticating)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Gate View
struct IOSLockGateView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var lockManager: IOSLockManager

    var body: some View {
        Group {
            if !lockManager.isTouchIDProtectionEnabled || lockManager.isUnlocked {
                iOSRootView()
                    .simultaneousGesture(
                        TapGesture().onEnded { _ in
                            lockManager.recordActivity()
                        }
                    )
            } else {
                IOSLockScreenView(lockManager: lockManager)
            }
        }
    }
}
#endif
