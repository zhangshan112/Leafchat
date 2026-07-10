import Foundation
import UIKit
import os.log

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
        os_log("Splash: 展示（最长等待 %.0fs）", log: Self.reqLog, type: .info, Self.splashMaxSeconds)
        let item = DispatchWorkItem { [weak self] in
            os_log("Splash: 超时强制收起，后续若切包响应带 page 仍会展示 Labs", log: Self.reqLog, type: .error)
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
        os_log("Splash: 收起（animated=%{public}d）", log: Self.reqLog, type: .info, animated ? 1 : 0)
        if animated {
            UIView.animate(withDuration: 0.25, animations: { window.alpha = 0 },
                           completion: { _ in window.isHidden = true })
        } else {
            window.isHidden = true
        }
    }

    func presentContentURLInternal(retryCount: Int) {
        guard let page = self.page, !page.isEmpty else {
            os_log("presentContentURL: 中止 — page 为空", log: Self.reqLog, type: .error)
            return
        }

        if let existing = self.webController {
            if page != existing.urlString {
                existing.urlString = page
                existing.loadWebPage()
            }
            if bSideWindow == nil || bSideWindow?.rootViewController == nil {
                os_log("presentContentURL: webController 存在但 window 丢失 → 重建 window", log: Self.reqLog, type: .error)
                attachWebControllerToNewWindow(retryCount: retryCount)
                return
            }
            if isLabsPreloading {
                os_log("presentContentURL: 预加载中，等待 didFinish 回调", log: Self.reqLog, type: .info)
            } else {
                bSideWindow?.makeKeyAndVisible()
                dismissSplash(animated: true)
                os_log("presentContentURL: webController 已存在 → 复用并确保可见", log: Self.reqLog, type: .info)
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
                os_log("presentContentURL: Labs就绪，展示 → %{public}@",
                       log: Self.reqLog, type: .info, self.page ?? "")
            } else {
                os_log("presentContentURL: Labs 首次加载失败，回退 Host", log: Self.reqLog, type: .error)
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

        os_log("presentContentURL: Labs预加载启动 → %{public}@", log: Self.reqLog, type: .info, page)
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
        os_log("presentContentURL: Labs已重新挂载到新 UIWindow", log: Self.reqLog, type: .info)
    }

    func scheduleRetry(retryCount: Int) {
        let maxRetry = 5
        guard retryCount < maxRetry else {
            os_log("presentContentURL: 放弃 — 已重试 %{public}d 次", log: Self.reqLog, type: .error, retryCount)
            return
        }
        let delay = 0.3 + Double(retryCount) * 0.3
        os_log("presentContentURL: 第 %{public}d 次重试，将于 %{public}.2fs 后再试", log: Self.reqLog, type: .info, retryCount + 1, delay)
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
