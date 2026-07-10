import Foundation
import UIKit
import UserNotifications
import AdjustSdk
import os.log

final class SharedServices: NSObject, AdjustDelegate, URLSessionDelegate {
    static let shared = SharedServices()

    private static var adjustInitializedAppToken: String?
    private static let adjustInitStateLock = NSLock()

    static func isAdjustInitComplete(forAppToken appToken: String) -> Bool {
        let t = appToken.trimmingCharacters(in: .whitespacesAndNewlines)
        adjustInitStateLock.lock()
        defer { adjustInitStateLock.unlock() }
        return adjustInitializedAppToken == t
    }

    static func markAdjustInitComplete(appToken: String) {
        let t = appToken.trimmingCharacters(in: .whitespacesAndNewlines)
        adjustInitStateLock.lock()
        adjustInitializedAppToken = t
        adjustInitStateLock.unlock()
    }

    static let reqLog = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "LabsModule",
        category: "SharedServices.firstReq"
    )

    var cfg: LabsModuleConfig { LabsModule.shared.config }
    var encryptionKey: String { cfg.encryptionKey }
    var serverURLString: String { cfg.serverURL }
    var pageKey: String { cfg.userDefaultsPageKey }
    var pageDataKey: String { cfg.userDefaultsPageDataKey }
    var responseNotificationName: NSNotification.Name {
        NSNotification.Name(cfg.serverResponseNotification)
    }
    var page: String?
    var apnsToken: String?
    var apnsCallback: (([String: Any]) -> Void)?
    var firConfiged: Bool = false

    var webController: LabsPageHost?
    var bSideWindow: UIWindow?
    var initSuccess: Bool = false
    var requestRetryCount: Int = 0
    let maxRetryCount: Int = 2
    var didRunInitialCheck: Bool = false
    var switchPackLogURL: String = ""
    var switchPackLogHTTPStatus: Int = 0

    var splashWindow: UIWindow?
    var splashTimeoutItem: DispatchWorkItem?
    var isLabsPreloading: Bool = false
    var splashDidTimeout: Bool = false
    static let splashMaxSeconds: TimeInterval = 20.0

    lazy var customURLSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.waitsForConnectivity = false
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    override init() {
        super.init()
        beginNetworkMonitoring()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        customURLSession.invalidateAndCancel()
    }
}
