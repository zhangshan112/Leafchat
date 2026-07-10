import UIKit
import WebKit
import AVFoundation
import os.log

private let labsPageHostLog = OSLog(
    subsystem: Bundle.main.bundleIdentifier ?? "LabsModule",
    category: "LabsPageHost"
)

/// Hosts the Labs WKWebView, JS bridge, loading cover, and media permission prompts.
final class LabsPageHost: UIViewController {

    var urlString: String = ""
    var bNativeOpen: Bool = false
    var bNativeHidden: Bool = false
    var allowsPushedPresentation: Bool = false
    var hidesNavigationBarOnAppear: Bool = true
    var onFirstLoadCompleted: ((Bool) -> Void)?

    private var contentView: WKWebView?
    private var bridgeHandlers: [JSEventDelegate] = []
    private var topBar: UIView?
    private var placeHolderImageView: UIImageView?
    private let loadingCover = PageLoadingCover()

    init(urlString: String) {
        super.init(nibName: nil, bundle: nil)
        self.urlString = urlString
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = ""
        os_log(
            "viewDidLoad: urlString=%{public}@ view.bounds=%{public}@",
            log: labsPageHostLog,
            type: .info,
            urlString,
            NSCoder.string(for: view.bounds)
        )

        guard shouldBootstrapContentView() else { return }

        let frame = view.bounds.isEmpty ? UIScreen.main.bounds : view.bounds
        let built = ContentViewFactory.make(
            frame: frame,
            scriptDelegate: self,
            uiDelegate: self,
            navigationDelegate: self
        )
        contentView = built
        view.addSubview(built)
        installBridgeHandlers(on: built)
        loadWebPage()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let contentView, topBar == nil, contentView.frame != view.bounds else { return }
        contentView.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(hidesNavigationBarOnAppear, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            contentView?.stopLoading()
            contentView?.evaluateJavaScript("window.stop();", completionHandler: nil)
        }
        if hidesNavigationBarOnAppear {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard bNativeHidden else { return }
        placeHolderImageView?.removeFromSuperview()
        placeHolderImageView = nil
        contentView?.removeFromSuperview()
        if let contentView {
            view.addSubview(contentView)
        }
        bNativeHidden = false
    }

    // MARK: - Public load APIs

    func loadWebPage() {
        if !urlString.hasPrefix("http://"), !urlString.hasPrefix("https://") {
            urlString = "https://\(urlString)"
        }

        guard let url = URL(string: urlString) else {
            os_log("loadWebPage: abort invalid URL %{public}@", log: labsPageHostLog, type: .error, urlString)
            presentLoadError("Invalid URL")
            return
        }
        guard let contentView else {
            os_log("loadWebPage: abort contentView nil", log: labsPageHostLog, type: .error)
            return
        }

        os_log("loadWebPage: start %{public}@", log: labsPageHostLog, type: .info, url.absoluteString)
        loadingCover.show(on: view)
        contentView.load(URLRequest(url: url))
    }

    func loadHTMLString(_ htmlString: String, baseURL: URL? = nil) {
        contentView?.loadHTMLString(htmlString, baseURL: baseURL)
    }

    func applyFlowConfiguration(navInfo: [String: Any]) {
        guard let isShow = navInfo["is_show"] as? Int else { return }

        if isShow == 1 {
            let navHeight = CGFloat((navInfo["nav_height"] as? Double) ?? 0)
            contentView?.frame = CGRect(
                x: 0,
                y: navHeight,
                width: view.frame.width,
                height: view.frame.height - navHeight
            )
            if topBar == nil {
                let bar = UIView()
                view.addSubview(bar)
                topBar = bar
            }
            topBar?.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: navHeight)
            if let bgColor = navInfo["bg_color"] as? String {
                topBar?.backgroundColor = UIColor.hexColor(bgColor)
            }
        } else {
            contentView?.frame = view.bounds
            topBar?.removeFromSuperview()
            topBar = nil
        }
    }

    // MARK: - Private helpers

    private func shouldBootstrapContentView() -> Bool {
        if bNativeOpen {
            os_log("viewDidLoad: skip bNativeOpen", log: labsPageHostLog, type: .info)
            return false
        }
        if !allowsPushedPresentation, (navigationController?.viewControllers.count ?? 0) > 1 {
            os_log(
                "viewDidLoad: skip nav depth %{public}d",
                log: labsPageHostLog,
                type: .error,
                navigationController?.viewControllers.count ?? 0
            )
            return false
        }
        return true
    }

    private func installBridgeHandlers(on webView: WKWebView) {
        bridgeHandlers = [LabsNativeBridge(webView: webView)]
    }

    private func presentLoadError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Sure", style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    private func consumeFirstLoadCallback(_ success: Bool) {
        guard let callback = onFirstLoadCompleted else { return }
        onFirstLoadCompleted = nil
        callback(success)
    }
}

// MARK: - WKWebView factory

private enum ContentViewFactory {
    static func make(
        frame: CGRect,
        scriptDelegate: WKScriptMessageHandler,
        uiDelegate: WKUIDelegate,
        navigationDelegate: WKNavigationDelegate
    ) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let imageScheme = LabsModule.shared.config?.imageScheme ?? "wdimg"
        configuration.setURLSchemeHandler(
            LabsAssetSchemeHandler(scheme: imageScheme),
            forURLScheme: imageScheme
        )
        configuration.userContentController.add(scriptDelegate, name: "callNative")

        let webView = WKWebView(frame: frame, configuration: configuration)
        webView.uiDelegate = uiDelegate
        webView.navigationDelegate = navigationDelegate
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.backgroundColor = .white
        webView.isOpaque = true
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = false
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        syncSharedCookies(into: webView)
        return webView
    }

    private static func syncSharedCookies(into webView: WKWebView) {
        let store = webView.configuration.websiteDataStore.httpCookieStore
        HTTPCookieStorage.shared.cookies?.forEach { store.setCookie($0) }
    }
}

// MARK: - In-page loading cover

private final class PageLoadingCover {
    private static let timeoutSeconds: TimeInterval = 15.0

    private var coverView: UIView?
    private var timeoutWorkItem: DispatchWorkItem?

    func show(on host: UIView) {
        guard let window = host.window, !window.isHidden, window.alpha > 0 else { return }

        if let existing = coverView {
            existing.alpha = 1
            host.bringSubviewToFront(existing)
            armTimeout()
            return
        }

        let color = LabsModule.shared.config?.splashBackgroundColor ?? .white
        let cover = UIView()
        cover.backgroundColor = color
        cover.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(cover)
        NSLayoutConstraint.activate([
            cover.topAnchor.constraint(equalTo: host.topAnchor),
            cover.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            cover.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            cover.bottomAnchor.constraint(equalTo: host.bottomAnchor),
        ])

        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()
        cover.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: cover.centerYAnchor),
        ])

        coverView = cover
        armTimeout()
        os_log("loadingCover: show", log: labsPageHostLog, type: .info)
    }

    func hide(animated: Bool) {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        guard let cover = coverView else { return }
        coverView = nil
        os_log("loadingCover: hide animated=%{public}d", log: labsPageHostLog, type: .info, animated ? 1 : 0)
        if animated {
            UIView.animate(withDuration: 0.25, animations: { cover.alpha = 0 }, completion: { _ in
                cover.removeFromSuperview()
            })
        } else {
            cover.removeFromSuperview()
        }
    }

    private func armTimeout() {
        timeoutWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            os_log("loadingCover: timeout", log: labsPageHostLog, type: .error)
            self?.hide(animated: true)
        }
        timeoutWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.timeoutSeconds, execute: item)
    }
}


// MARK: - Navigation

extension LabsPageHost: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        os_log("WK start → %{public}@", log: labsPageHostLog, type: .info, webView.url?.absoluteString ?? "nil")
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        os_log("WK commit → %{public}@", log: labsPageHostLog, type: .info, webView.url?.absoluteString ?? "nil")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        title = webView.title
        loadingCover.hide(animated: true)
        os_log(
            "WK finish → %{public}@ title=%{public}@ frame=%{public}@",
            log: labsPageHostLog,
            type: .info,
            webView.url?.absoluteString ?? "nil",
            webView.title ?? "",
            NSCoder.string(for: webView.frame)
        )
        consumeFirstLoadCallback(true)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsErr = error as NSError
        os_log(
            "WK failProvisional domain=%{public}@ code=%{public}d desc=%{public}@",
            log: labsPageHostLog,
            type: .error,
            nsErr.domain,
            nsErr.code,
            nsErr.localizedDescription
        )
        loadingCover.hide(animated: false)
        if onFirstLoadCompleted != nil {
            consumeFirstLoadCallback(false)
        } else if view.window != nil {
            presentLoadError(error.localizedDescription)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nsErr = error as NSError
        os_log(
            "WK fail domain=%{public}@ code=%{public}d desc=%{public}@",
            log: labsPageHostLog,
            type: .error,
            nsErr.domain,
            nsErr.code,
            nsErr.localizedDescription
        )
        loadingCover.hide(animated: false)
        // Preserve original behavior: report success to first-load callback on didFail.
        consumeFirstLoadCallback(true)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        os_log("WK process terminated → reload", log: labsPageHostLog, type: .error)
        webView.reload()
    }
}

// MARK: - UI / media

extension LabsPageHost: WKUIDelegate {
    @available(iOS 15.0, *)
    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        let answer: (Bool) -> Void = { grant in
            DispatchQueue.main.async {
                decisionHandler(grant ? .grant : .deny)
            }
        }
        switch type {
        case .camera:
            MediaPermission.requestCamera(answer)
        case .microphone:
            MediaPermission.requestMicrophone(answer)
        case .cameraAndMicrophone:
            MediaPermission.requestCameraAndMicrophone(answer)
        @unknown default:
            answer(false)
        }
    }
}

private enum MediaPermission {
    static func requestCamera(_ completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    static func requestMicrophone(_ completion: @escaping (Bool) -> Void) {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            completion(true)
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission(completion)
        case .denied:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    static func requestCameraAndMicrophone(_ completion: @escaping (Bool) -> Void) {
        requestCamera { cameraOK in
            guard cameraOK else {
                completion(false)
                return
            }
            requestMicrophone(completion)
        }
    }
}

// MARK: - JS bridge

extension LabsPageHost: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "callNative" else { return }

        let params: [String: Any]?
        if let stringBody = message.body as? String,
           let data = stringBody.data(using: .utf8) {
            params = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        } else if let dictBody = message.body as? [String: Any] {
            params = dictBody
        } else {
            params = nil
        }

        guard let params else {
            contentView?.evaluateJavaScript("console.error('Native Error: Invalid JSON format')", completionHandler: nil)
            return
        }

        logBridgeParams(params)
        dispatchBridgeCall(params)
    }

    private func dispatchBridgeCall(_ params: [String: Any]) {
        guard
            let actionStr = params["action"] as? String,
            let actionNum = Int(actionStr),
            let callbackID = params["callbackID"] as? String
        else {
            os_log("[JSBridge] abort invalid action/callbackID %{public}@", log: labsPageHostLog, type: .error, String(describing: params))
            return
        }

        guard LabsBridgeAction.recognizes(actionNum) else {
            os_log("[JSBridge] unknown action=%{public}d callbackID=%{public}@", log: labsPageHostLog, type: .error, actionNum, callbackID)
            CoreScriptInteractor.replyUnknownMethod(on: contentView, callbackID: callbackID)
            return
        }

        for handler in bridgeHandlers where handler.supportedActions().contains(actionNum) {
            os_log(
                "[JSBridge] dispatch action=%{public}d → %{public}@ callbackID=%{public}@",
                log: labsPageHostLog,
                type: .info,
                actionNum,
                String(describing: type(of: handler)),
                callbackID
            )
            handler.handleJSCall(params: params, callbackID: callbackID)
            return
        }

        os_log(
            "[JSBridge] no handler action=%{public}d count=%{public}d",
            log: labsPageHostLog,
            type: .error,
            actionNum,
            bridgeHandlers.count
        )
    }

    private func logBridgeParams(_ params: [String: Any]) {
        guard
            JSONSerialization.isValidJSONObject(params),
            let data = try? JSONSerialization.data(withJSONObject: params, options: [.prettyPrinted, .sortedKeys]),
            let json = String(data: data, encoding: .utf8)
        else {
            os_log("[JSBridge] params raw → %{public}@", log: labsPageHostLog, type: .info, String(describing: params))
            return
        }
        os_log("[JSBridge] params →\n%{public}@", log: labsPageHostLog, type: .info, json)
    }
}
