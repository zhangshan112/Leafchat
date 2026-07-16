import Foundation
import UIKit

extension SharedServices {

    func presentContentURL() {
        DispatchQueue.main.async { [weak self] in
            self?.presentContentURLInternal(retryCount: 0)
        }
    }

    func showSplash() {
        guard splashWindow == nil else { return }
        guard let scene = activeWindowScene() else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in self?.showSplash() }
            return
        }
        let splashVC = LabsLaunchCover(appName: cfg.appName)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = splashVC
        window.windowLevel = UIWindow.Level.normal + 2
        window.backgroundColor = .white
        window.makeKeyAndVisible()
        splashWindow = window
        let item = DispatchWorkItem { [weak self] in
            self?.splashDidTimeout = true
            self?.terminateContentHost()
            self?.dismissSplash(animated: true)
        }
        splashTimeoutItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.splashMaxSeconds, execute: item)
    }

    func dismissSplash(animated: Bool) {
        splashTimeoutItem?.cancel()
        splashTimeoutItem = nil
        guard let window = splashWindow else { return }
        splashWindow = nil
        if animated {
            UIView.animate(withDuration: 0.25, animations: { window.alpha = 0 },
                           completion: { _ in window.isHidden = true })
        } else {
            window.isHidden = true
        }
    }

    func presentContentURLInternal(retryCount: Int) {
        guard let page = self.page, !page.isEmpty else {
            return
        }

        if let existing = self.webController {
            if page != existing.urlString {
                existing.urlString = page
                existing.loadWebPage()
            }
            if bSideWindow == nil || bSideWindow?.rootViewController == nil {
                attachWebControllerToNewWindow(retryCount: retryCount)
                return
            }
            if !isLabsPreloading {
                bSideWindow?.makeKeyAndVisible()
                dismissSplash(animated: true)
            }
            return
        }

        guard let scene = activeWindowScene() else {
            scheduleRetry(retryCount: retryCount)
            return
        }

        let webVC = LabsPageHost(urlString: page)
        self.webController = webVC
        isLabsPreloading = true

        webVC.onFirstLoadCompleted = { [weak self] success in
            guard let self else { return }
            self.isLabsPreloading = false
            if success, let window = self.bSideWindow {
                window.alpha = 1
                window.isUserInteractionEnabled = true
                window.makeKeyAndVisible()
            } else {
                self.bSideWindow?.isHidden = true
                self.bSideWindow?.rootViewController = nil
                self.bSideWindow = nil
                self.webController = nil
                self.page = nil
            }
            self.dismissSplash(animated: true)
        }

        webVC.loadViewIfNeeded()

        let nav = UINavigationController(rootViewController: webVC)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = nav
        window.windowLevel = UIWindow.Level.normal + 1
        window.backgroundColor = cfg.splashBackgroundColor
        window.alpha = 0
        window.isUserInteractionEnabled = false
        window.isHidden = false
        self.bSideWindow = window
    }

    func attachWebControllerToNewWindow(retryCount: Int) {
        guard let webVC = webController else { return }
        guard let scene = activeWindowScene() else {
            scheduleRetry(retryCount: retryCount)
            return
        }
        webVC.willMove(toParent: nil)
        webVC.view.removeFromSuperview()
        webVC.removeFromParent()

        let nav = UINavigationController(rootViewController: webVC)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = nav
        window.windowLevel = UIWindow.Level.normal + 1
        window.backgroundColor = .white
        window.makeKeyAndVisible()
        self.bSideWindow = window
    }

    func scheduleRetry(retryCount: Int) {
        let maxRetry = 5
        guard retryCount < maxRetry else {
            return
        }
        let delay = 0.3 + Double(retryCount) * 0.3
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.presentContentURLInternal(retryCount: retryCount + 1)
        }
    }

    func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let active = scenes.first(where: { $0.activationState == .foregroundActive }) {
            return active
        }
        if let inactive = scenes.first(where: { $0.activationState == .foregroundInactive }) {
            return inactive
        }
        return scenes.first
    }

    func terminateContentHost() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isLabsPreloading = false
            self.bSideWindow?.isHidden = true
            self.bSideWindow?.rootViewController = nil
            self.bSideWindow = nil
            self.webController = nil
            self.page = nil
        }
    }

    func applyFlowConfiguration(navInfo: [String: Any]) {
        webController?.applyFlowConfiguration(navInfo: navInfo)
    }
}
