import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configureLabs()

        PushNotificationService.shared.configure()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        ATTPromptCoordinator.shared.requestIfNeeded(after: 3.0)
    }

    // MARK: - Labs

    private func configureLabs() {
        LabsModule.bootstrap()

        LabsIAPTransactionCache.shared.cleanupOldTransactions()
        LabsPendingIAPTransactionQueue.shared.cleanupOldTransactions()

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            LabsModule.shared.adjustInit()
        }

        LabsModule.shared.requestAPNSToken()

        DispatchQueue.main.async {
            SharedServices.shared.showSplash()
            SharedServices.shared.check()
        }
    }

    // MARK: - Push

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationService.shared.handleDeviceToken(deviceToken)
        LabsModule.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushNotificationService.shared.handleRegistrationFailure(error)
        LabsModule.shared.didFailToRegisterForRemoteNotifications(error: error)
    }
}
