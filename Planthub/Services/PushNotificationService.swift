import Combine
import Foundation
import OSLog
import UIKit
import UserNotifications

@MainActor
final class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var deviceToken: String?
    @Published private(set) var lastRegistrationError: String?

    private let tokenStore = DeviceTokenStore.shared
    private let preferencesStore = PushNotificationPreferencesStore.shared
    private let logger = Logger(subsystem: "com.planthub", category: "PushNotifications")

    private override init() {
        super.init()
        deviceToken = tokenStore.token
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        Task { await refreshAuthorizationStatus() }
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            await refreshAuthorizationStatus()

            if granted {
                registerForRemoteNotifications()
            }

            return granted
        } catch {
            logger.error("Push authorization request failed: \(error.localizedDescription)")
            lastRegistrationError = error.localizedDescription
            return false
        }
    }

    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func handleDeviceToken(_ data: Data) {
        let token = data.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = token
        tokenStore.save(token)
        logger.info("APNs device token registered.")
    }

    func handleRegistrationFailure(_ error: Error) {
        lastRegistrationError = error.localizedDescription
        logger.error("APNs registration failed: \(error.localizedDescription)")
    }

    func updatePreferences(_ preferences: PushNotificationPreferences) {
        preferencesStore.preferences = preferences
    }

    func openSystemNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func handleNotificationResponse(userInfo: [AnyHashable: Any]) {
        let payload = PushNotificationPayload(userInfo: userInfo)
        logger.info("Notification tapped: \(payload.category?.rawValue ?? "unknown")")
        // Future: route to Post Detail, User Profile, or Chat based on payload.
    }
}

extension PushNotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in
            completionHandler([.banner, .sound, .badge])
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            handleNotificationResponse(userInfo: userInfo)
            completionHandler()
        }
    }
}
