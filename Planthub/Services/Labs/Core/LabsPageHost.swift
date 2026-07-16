import UIKit
import WebKit
import AVFoundation

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
            presentLoadError("Invalid URL")
            return
        }
        guard let contentView else { return }

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
            return false
        }
        if !allowsPushedPresentation, (navigationController?.viewControllers.count ?? 0) > 1 {
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
    }

    func hide(animated: Bool) {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        guard let cover = coverView else { return }
        coverView = nil
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
            self?.hide(animated: true)
        }
        timeoutWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.timeoutSeconds, execute: item)
    }
}


// MARK: - Navigation

extension LabsPageHost: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        title = webView.title
        loadingCover.hide(animated: true)
        consumeFirstLoadCallback(true)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loadingCover.hide(animated: false)
        if onFirstLoadCompleted != nil {
            consumeFirstLoadCallback(false)
        } else if view.window != nil {
            presentLoadError(error.localizedDescription)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadingCover.hide(animated: false)
        // Preserve original behavior: report success to first-load callback on didFail.
        consumeFirstLoadCallback(true)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
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

        dispatchBridgeCall(params)
    }

    private func dispatchBridgeCall(_ params: [String: Any]) {
        guard
            let actionStr = params["action"] as? String,
            let actionNum = Int(actionStr),
            let callbackID = params["callbackID"] as? String
        else {
            return
        }

        guard LabsBridgeAction.recognizes(actionNum) else {
            CoreScriptInteractor.replyUnknownMethod(on: contentView, callbackID: callbackID)
            return
        }

        for handler in bridgeHandlers where handler.supportedActions().contains(actionNum) {
            handler.handleJSCall(params: params, callbackID: callbackID)
            return
        }
    }
}
