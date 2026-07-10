import UIKit
import AppTrackingTransparency

final class ATTPromptCoordinator {
    static let shared = ATTPromptCoordinator()
    private init() {}

    private var didFire = false
    private var didEnqueueObserver = false
    private let lock = NSLock()

    func requestIfNeeded(after delay: TimeInterval = 0.5) {
        lock.lock()
        let alreadyFired = didFire
        lock.unlock()
        guard !alreadyFired else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.tryPresent()
        }
    }

    private func tryPresent() {
        if #available(iOS 14.0, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            guard status == .notDetermined else {
                lock.lock(); didFire = true; lock.unlock()
                return
            }

            if UIApplication.shared.applicationState != .active {
                enqueueDidBecomeActiveObserverOnce()
                return
            }

            lock.lock()
            if didFire { lock.unlock(); return }
            didFire = true
            lock.unlock()

            ATTrackingManager.requestTrackingAuthorization { _ in }
        }
    }

    private func enqueueDidBecomeActiveObserverOnce() {
        lock.lock()
        if didEnqueueObserver { lock.unlock(); return }
        didEnqueueObserver = true
        lock.unlock()

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.tryPresent()
        }
    }
}
