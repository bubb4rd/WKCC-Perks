import Foundation
import UIKit
import UserNotifications

/// Requests notification permission and registers the APNs device token with the backend.
@MainActor
final class PushNotificationManager: NSObject {
    static let shared = PushNotificationManager()

    private(set) var deviceTokenHex: String? {
        didSet {
            if let deviceTokenHex {
                UserDefaults.standard.set(deviceTokenHex, forKey: Self.tokenDefaultsKey)
            }
        }
    }

    private static let tokenDefaultsKey = "wkcc.pushDeviceToken"

    private var hasRequestedThisSession = false

    private override init() {
        super.init()
        deviceTokenHex = UserDefaults.standard.string(forKey: Self.tokenDefaultsKey)
    }

    /// Call after a live member session is established.
    func startIfNeeded() {
        guard !AppConfig.useMockAuth else { return }
        guard !hasRequestedThisSession else {
            if let token = deviceTokenHex {
                Task { await uploadToken(token) }
            }
            return
        }
        hasRequestedThisSession = true

        UNUserNotificationCenter.current().delegate = self
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            switch settings.authorizationStatus {
            case .notDetermined:
                let granted = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
                guard granted == true else { return }
                UIApplication.shared.registerForRemoteNotifications()
            case .authorized, .provisional, .ephemeral:
                UIApplication.shared.registerForRemoteNotifications()
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    func didRegister(deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        deviceTokenHex = hex
        Task { await uploadToken(hex) }
    }

    func didFailToRegister(error: Error) {
        print("APNs registration failed: \(error.localizedDescription)")
    }

    /// Unregister current token from the backend and stop session registration flag.
    func stopAndUnregister() async {
        hasRequestedThisSession = false
        let token = deviceTokenHex
        await PushDeviceTokenService.unregister(token: token)
    }

    private func uploadToken(_ token: String) async {
        guard !AppConfig.useMockAuth else { return }
        do {
            try await PushDeviceTokenService.register(token: token)
        } catch {
            print("Failed to upload push token: \(error.localizedDescription)")
        }
    }
}

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.didRegister(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.didFailToRegister(error: error)
        }
    }
}
