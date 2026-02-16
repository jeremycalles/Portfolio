import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

@main
struct PortfolioApp: App {
    @StateObject private var viewModel = AppViewModel()
    @StateObject private var languageManager = LanguageManager.shared
    
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    #endif
    
    var body: some Scene {
        #if os(iOS)
        WindowGroup {
            IOSLockGateView()
                .environmentObject(viewModel)
                .environmentObject(languageManager)
                .environmentObject(IOSLockManager.shared)
                .id(languageManager.refreshID)  // Force view refresh on language change
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                if IOSLockManager.shared.isTouchIDProtectionEnabled {
                    IOSLockManager.shared.lock()
                }
                BackgroundTaskManager.shared.appDidEnterBackground()
            case .active:
                BackgroundTaskManager.shared.appDidBecomeActive()
            default:
                break
            }
        }
        #else
        WindowGroup {
            MacOSLockGateView()
                .environmentObject(viewModel)
                .environmentObject(languageManager)
                .environmentObject(MacOSLockManager.shared)
                .id(languageManager.refreshID)  // Force view refresh on language change
                .onOpenURL { url in
                    guard url.scheme == "portfolio", url.host == "refresh" else { return }
                    Task {
                        await MacOSSchedulerManager.shared.performBackgroundRefresh()
                    }
                }
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) { }
            
            CommandMenu(L10n.generalData) {
                Button(L10n.actionUpdateAllPrices) {
                    NotificationCenter.default.post(name: .updatePrices, object: nil)
                }
                .keyboardShortcut("u", modifiers: [.command])
                
                Divider()
                
                Button(L10n.actionBackfillHistorical1Year) {
                    NotificationCenter.default.post(name: .backfillHistorical, object: "1y")
                }
                
                Button(L10n.actionBackfillHistorical2Years) {
                    NotificationCenter.default.post(name: .backfillHistorical, object: "2y")
                }
                
                Button(L10n.actionBackfillHistorical5Years) {
                    NotificationCenter.default.post(name: .backfillHistorical, object: "5y")
                }
            }
        }
        
        Settings {
            MacOSSystemSettingsView()
                .environmentObject(viewModel)
                .environmentObject(languageManager)
                .environmentObject(MacOSLockManager.shared)
                .id(languageManager.refreshID)  // Force view refresh on language change
        }
        #endif
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let updatePrices = Notification.Name("updatePrices")
    static let backfillHistorical = Notification.Name("backfillHistorical")
    static let databaseDidImport = Notification.Name("databaseDidImport")
}

// MARK: - iOS App Delegate
#if os(iOS)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Register background tasks (required for handler to run)
        BackgroundTaskManager.shared.registerBackgroundTasks()
        // Schedule a refresh so one is queued even if user never sends app to background
        BackgroundTaskManager.shared.scheduleAppRefresh()
        return true
    }
}
#endif
