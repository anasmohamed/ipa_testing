// NETWATCH — NWServices.swift
// Notification alerts + scan history persistence.

import Foundation
import UIKit
import UserNotifications

// ── Notifications ─────────────────────────────────────────
final class NWNotifications: NSObject {
    static let shared = NWNotifications()
    private override init() { super.init() }

    func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    func authStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func alert(for device: NetworkDevice) {
        let content        = UNMutableNotificationContent()
        content.title      = "[\(device.highestRisk.rawValue)] \(device.ipAddress)"
        content.subtitle   = device.hostname ?? device.ipAddress
        let ports = device.suspiciousPorts.prefix(3).map { ":\($0.port)/\($0.service)" }.joined(separator: "  ")
        content.body       = ports.isEmpty ? "Suspicious device detected" : ports
        content.sound      = device.highestRisk == .critical ? .defaultCritical : .default
        content.badge      = 1
        content.userInfo   = ["ip": device.ipAddress, "risk": device.highestRisk.rawValue]
        let req = UNNotificationRequest(
            identifier: "nw-\(device.ipAddress)-\(Int(Date().timeIntervalSince1970))",
            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req) { _ in }
    }

    func scanComplete(result: ScanResult) {
        let content   = UNMutableNotificationContent()
        content.title = "NETWATCH — Scan Complete"
        content.body  = result.threatCount == 0
            ? "✓ \(result.devices.count) devices — network clear"
            : "⚠ \(result.threatCount) threat(s) on \(result.devices.count) devices"
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "nw-done-\(Int(Date().timeIntervalSince1970))",
                                  content: content, trigger: nil)) { _ in }
    }

    func resetBadge() {
        UIApplication.shared.applicationIconBadgeNumber = 0
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

extension NWNotifications: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner, .sound, .badge])
    }
}

// ── Scan History ──────────────────────────────────────────
final class NWScanHistory: ObservableObject {
    static let shared = NWScanHistory()
    @Published private(set) var history: [ScanResult] = []
    private let max = 50

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("nw_history.json")
    }

    private init() { load() }

    func save(_ result: ScanResult) {
        history.insert(result, at: 0)
        if history.count > max { history = Array(history.prefix(max)) }
        persist()
    }

    func clear() { history = []; try? FileManager.default.removeItem(at: fileURL) }

    private func persist() {
        if let data = try? JSONEncoder().encode(history) { try? data.write(to: fileURL) }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ScanResult].self, from: data)
        else { return }
        history = decoded
    }
}
