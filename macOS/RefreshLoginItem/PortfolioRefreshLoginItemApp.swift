#if os(macOS)
import AppKit
import CoreFoundation

/// Headless login item: wakes at login and requests refreshes from the main app without opening windows.
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
    private var activityScheduler: NSBackgroundActivityScheduler?
    private var keepAlive: NSObjectProtocol?
    private var defaultsRetryCount = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        keepAlive = ProcessInfo.processInfo.beginActivity(
            options: [.automaticTerminationDisabled, .suddenTerminationDisabled],
            reason: "Portfolio scheduled refresh helper"
        )
        registerDarwinObserver()
        rescheduleFromSharedDefaults()
    }

    func applicationWillTerminate(_ notification: Notification) {
        activityScheduler?.invalidate()
        timer?.invalidate()
        if let keepAlive {
            ProcessInfo.processInfo.endActivity(keepAlive)
        }
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
        activityScheduler?.invalidate()
        activityScheduler = nil
        timer?.invalidate()
        timer = nil

        guard let suite = UserDefaults(suiteName: PortfolioRefreshBridge.appGroupIdentifier) else {
            defaultsRetryCount += 1
            if defaultsRetryCount < 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.rescheduleFromSharedDefaults()
                }
            } else {
                NSApp.terminate(nil)
            }
            return
        }
        defaultsRetryCount = 0

        guard suite.bool(forKey: PortfolioRefreshBridge.backgroundRefreshEnabledKey) else {
            NSApp.terminate(nil)
            return
        }

        let raw = suite.integer(forKey: PortfolioRefreshBridge.refreshIntervalSecondsKey)
        let seconds = raw > 0 ? raw : PortfolioRefreshBridge.defaultRefreshIntervalSeconds
        let interval = TimeInterval(seconds)

        requestRefreshFromMainApp()

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.requestRefreshFromMainApp()
        }
        if let timer {
            timer.tolerance = min(interval * 0.1, 60)
            RunLoop.main.add(timer, forMode: .common)
        }

        // Survives App Nap better than Timer alone when the helper is idle for hours.
        let scheduler = NSBackgroundActivityScheduler(identifier: "com.portfolio.app.refresh.loginItem")
        scheduler.repeats = true
        scheduler.interval = interval
        scheduler.tolerance = min(interval * 0.15, 15 * 60)
        scheduler.qualityOfService = .utility
        scheduler.schedule { [weak self] completion in
            self?.requestRefreshFromMainApp()
            completion(.finished)
        }
        activityScheduler = scheduler
    }

    /// Darwin notify is delivered only to a running process. If the main app was quit, wake it first.
    private func requestRefreshFromMainApp() {
        let running = NSRunningApplication.runningApplications(
            withBundleIdentifier: PortfolioRefreshBridge.mainAppBundleIdentifier
        )
        if !running.isEmpty {
            postRefreshRequest()
            return
        }
        launchParentThenNotify()
    }

    private func launchParentThenNotify() {
        let parentURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.createsNewApplicationInstance = false

        if FileManager.default.fileExists(atPath: parentURL.path) {
            NSWorkspace.shared.openApplication(at: parentURL, configuration: configuration) { [weak self] _, error in
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    self?.postRefreshRequest()
                    if error != nil, let url = PortfolioRefreshBridge.refreshURL {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            return
        }

        if let url = PortfolioRefreshBridge.refreshURL {
            NSWorkspace.shared.open(url)
        }
    }

    private func postRefreshRequest() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(PortfolioRefreshBridge.refreshRequestDarwinNotification),
            nil,
            nil,
            true
        )
    }
}

#endif
