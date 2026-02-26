#if os(macOS)
import SwiftUI
import AppKit

private let touchIDProtectionEnabledKey = "macos_touch_id_protection_enabled"

// MARK: - macOS Lock Manager
@MainActor
final class MacOSLockManager: ObservableObject {
    static let shared = MacOSLockManager()
    
    @Published private(set) var isUnlocked = false
    @Published var unlockErrorMessage: String?
    
    /// When true, dashboard is gated by Touch ID and locks after 5 min inactivity. When false, content is always visible.
    @Published var isTouchIDProtectionEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isTouchIDProtectionEnabled, forKey: touchIDProtectionEnabledKey)
            if isTouchIDProtectionEnabled {
                lock()
            } else {
                isUnlocked = true
                stopInactivityMonitoring()
            }
        }
    }
    
    private var lastActivityDate = Date()
    private let inactivityInterval: TimeInterval = 300 // 5 minutes
    private var inactivityTimer: Timer?
    private var activityMonitor: Any?
    
    private init() {
        self.isTouchIDProtectionEnabled = UserDefaults.standard.object(forKey: touchIDProtectionEnabledKey) as? Bool ?? false
    }
    
    /// Unlock via Touch ID or device password. On success, sets isUnlocked and starts activity monitoring.
    func unlock(reason: String) async {
        unlockErrorMessage = nil
        do {
            let success = try await BiometricAuth.evaluate(localizedReason: reason)
            if success {
                isUnlocked = true
                recordActivity()
                startInactivityMonitoring()
            }
        } catch {
            unlockErrorMessage = error.localizedDescription
        }
    }
    
    /// Lock the app and stop monitoring.
    func lock() {
        isUnlocked = false
        stopInactivityMonitoring()
    }
    
    /// Call when user interacts with the app; resets the 5-minute inactivity window.
    func recordActivity() {
        lastActivityDate = Date()
    }
    
    private func startInactivityMonitoring() {
        stopInactivityMonitoring()
        
        activityMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]) { [weak self] event in
            Task { @MainActor in
                self?.recordActivity()
            }
            return event
        }
        
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
    
    private func stopInactivityMonitoring() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        if let monitor = activityMonitor {
            NSEvent.removeMonitor(monitor)
            activityMonitor = nil
        }
    }
}

// MARK: - Lock Screen View
struct MacOSLockScreenView: View {
    @ObservedObject var lockManager: MacOSLockManager
    @State private var isAuthenticating = false
    
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .opacity(0.98)
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
                    Label(L10n.lockUnlockButton, systemImage: "touchid")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isAuthenticating)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
#endif
