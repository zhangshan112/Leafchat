import Foundation
import UIKit

///
public final class LabsModule {

    public static let shared = LabsModule()

    public private(set) var config: LabsModuleConfig!

    private var sharedServices: SharedServices { SharedServices.shared }

    private var didBootstrap = false

    private init() {}

    public static func bootstrap(config: LabsModuleConfig = LabsModuleConfig()) {
        shared.bootstrapInternal(config: config)
    }

    private func bootstrapInternal(config: LabsModuleConfig) {
        if didBootstrap {
            return
        }
        self.config = config
        didBootstrap = true

        LabsIAPManager.shared.bootstrap()

    }


    public func adjustInit() { sharedServices.adjustInit() }

    public func requestAPNSToken() { sharedServices.requestAPNSToken() }

    public func check() { sharedServices.check() }

    public func didRegisterForRemoteNotifications(deviceToken: Data) {
        sharedServices.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    public func didFailToRegisterForRemoteNotifications(error: Error) {
        sharedServices.didFailToRegisterForRemoteNotifications(error: error)
    }
}
