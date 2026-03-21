#if os(macOS)
import AppKit
import CoreFoundation

/// Headless login item: wakes at login and opens `portfolio://refresh` on a timer so the main sandboxed app performs the refresh.
@main
enum PortfolioRefreshLoginItemApp {
    static func main() {
        NSApplication.shared.setActivationPolicy(.accessory)
        let delegate = RefreshLoginItemDelegate()
        NSApplication.shared.delegate = delegate
        NSApplication.shared.run()
    }
}

private final class RefreshLoginItemDelegate: NSObject, NSApplicationDelegate {
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerDarwinObserver()
        rescheduleFromSharedDefaults()
    }

    func applicationWillTerminate(_ notification: Notification) {
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
    }

    private func registerDarwinObserver() {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let raw = observer else { return }
                let delegate = Unmanaged<RefreshLoginItemDelegate>.fromOpaque(raw).takeUnretainedValue()
                DispatchQueue.main.async {
                    delegate.rescheduleFromSharedDefaults()
                }
            },
            PortfolioRefreshBridge.refreshPrefsDarwinNotification,
            nil,
            .deliverImmediately
        )
    }

    private func rescheduleFromSharedDefaults() {
        timer?.invalidate()
        timer = nil

        guard let suite = UserDefaults(suiteName: PortfolioRefreshBridge.appGroupIdentifier) else {
            NSApp.terminate(nil)
            return
        }

        guard suite.bool(forKey: PortfolioRefreshBridge.backgroundRefreshEnabledKey) else {
            NSApp.terminate(nil)
            return
        }

        let raw = suite.integer(forKey: PortfolioRefreshBridge.refreshIntervalSecondsKey)
        let seconds = raw > 0 ? raw : PortfolioRefreshBridge.defaultRefreshIntervalSeconds
        let interval = TimeInterval(seconds)

        openRefreshURL()

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.openRefreshURL()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func openRefreshURL() {
        NSWorkspace.shared.open(PortfolioRefreshBridge.refreshURL)
    }
}

#endif
