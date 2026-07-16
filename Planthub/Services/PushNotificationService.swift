import Combine
import Foundation
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

            ATTPromptCoordinator.shared.requestIfNeeded()

            return granted
        } catch {
            lastRegistrationError = error.localizedDescription
            ATTPromptCoordinator.shared.requestIfNeeded()
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
    }

    func handleRegistrationFailure(_ error: Error) {
        lastRegistrationError = error.localizedDescription
    }

    func updatePreferences(_ preferences: PushNotificationPreferences) {
        preferencesStore.preferences = preferences
    }

    func openSystemNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func handleNotificationResponse(userInfo _: [AnyHashable: Any]) {
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
