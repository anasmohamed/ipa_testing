// NETWATCH — NETWATCHApp.swift

import SwiftUI
import UserNotifications

@available(iOS 16.0, *)
@main
struct NETWATCHApp: App {
    @UIApplicationDelegateAdaptor(NWAppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}

final class NWAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = NWNotifications.shared
        return true
    }
    func applicationDidBecomeActive(_ application: UIApplication) {
        NWNotifications.shared.resetBadge()
    }
}
