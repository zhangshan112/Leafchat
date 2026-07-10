import Foundation
@preconcurrency import WebKit
import Kingfisher

/// Custom-scheme image loader for Labs pages (`imageScheme://` → https + Kingfisher cache).
final class LabsAssetSchemeHandler: NSObject, WKURLSchemeHandler {

    private let schemePrefix: String
    private let sessionStore = LoadSessionStore()

    private static let kingfisherOptions: KingfisherOptionsInfo = {
        var serializer = DefaultCacheSerializer()
        serializer.preferCacheOriginalData = true
        return [.cacheOriginalImage, .cacheSerializer(serializer)]
    }()

    init(scheme: String) {
        self.schemePrefix = scheme + "://"
        super.init()
    }

    // MARK: - WKURLSchemeHandler

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url else { return }

        switch SchemeURLResolver.resolve(requestURL, prefix: schemePrefix) {
        case .failure(let error):
            urlSchemeTask.didFailWithError(error)
        case .success(let remoteURL):
            let token = LoadToken(urlSchemeTask)
            Task { [weak self] in
                guard let self else { return }
                await self.sessionStore.begin(token)
                self.startImageFetch(
                    task: urlSchemeTask,
                    token: token,
                    requestURL: requestURL,
                    remoteURL: remoteURL
                )
            }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        let token = LoadToken(urlSchemeTask)
        Task { [weak self] in
            guard let download = await self?.sessionStore.abort(token) else { return }
            download.cancel()
        }
    }

    // MARK: - Fetch

    private func startImageFetch(
        task: WKURLSchemeTask,
        token: LoadToken,
        requestURL: URL,
        remoteURL: URL
    ) {
        let download = KingfisherManager.shared.retrieveImage(
            with: remoteURL,
            options: Self.kingfisherOptions
        ) { [weak self] result in
            guard let self else { return }
            Task { @MainActor [weak self] in
                await self?.handleFetchResult(
                    result,
                    task: task,
                    token: token,
                    requestURL: requestURL,
                    remoteURL: remoteURL
                )
            }
        }

        Task { [weak self] in
            await self?.sessionStore.bind(download, to: token)
        }
    }

    @MainActor
    private func handleFetchResult(
        _ result: Result<RetrieveImageResult, KingfisherError>,
        task: WKURLSchemeTask,
        token: LoadToken,
        requestURL: URL,
        remoteURL: URL
    ) async {
        guard await sessionStore.isActive(token) else { return }

        switch result {
        case .failure(let error):
            await finishWithFailure(task, token: token, error: error)

        case .success(let value):
            guard let payload = ImagePayload.make(from: value), !payload.bytes.isEmpty else {
                await finishWithFailure(
                    task,
                    token: token,
                    error: SchemeURLResolver.makeError(code: -2, message: "Missing image data")
                )
                return
            }
            guard await sessionStore.isActive(token) else { return }

            #if DEBUG
            print("LabsAssetSchemeHandler cache=\(value.cacheType)")
            #endif

            let response = URLResponse(
                url: requestURL,
                mimeType: payload.mimeType(for: remoteURL),
                expectedContentLength: payload.bytes.count,
                textEncodingName: nil
            )
            task.didReceive(response)
            task.didReceive(payload.bytes)
            task.didFinish()
            await sessionStore.end(token)
        }
    }

    @MainActor
    private func finishWithFailure(_ task: WKURLSchemeTask, token: LoadToken, error: Error) async {
        guard await sessionStore.isActive(token) else { return }
        task.didFailWithError(error)
        await sessionStore.end(token)
    }
}

// MARK: - URL rewrite

private enum SchemeURLResolver {
    enum Outcome {
        case success(URL)
        case failure(Error)
    }

    static func resolve(_ url: URL, prefix: String) -> Outcome {
        let raw = url.absoluteString
        guard raw.hasPrefix(prefix) else {
            return .failure(makeError(code: -1, message: "Invalid scheme"))
        }
        let httpsURLString = "https://" + raw.dropFirst(prefix.count)
        guard let httpsURL = URL(string: httpsURLString) else {
            return .failure(makeError(code: -1, message: "Invalid URL"))
        }
        return .success(httpsURL)
    }

    static func makeError(code: Int, message: String) -> NSError {
        NSError(
            domain: "LabsAssetSchemeHandler",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}

// MARK: - Image payload / MIME

private struct ImagePayload {
    let bytes: Data

    static func make(from result: RetrieveImageResult) -> ImagePayload? {
        if let original = result.data(), !original.isEmpty {
            return ImagePayload(bytes: original)
        }
        guard let encoded = result.image.kf.data(format: .unknown), !encoded.isEmpty else {
            return nil
        }
        return ImagePayload(bytes: encoded)
    }

    func mimeType(for remoteURL: URL) -> String {
        let ext = remoteURL.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "": return Self.mimeType(for: bytes.kf.imageFormat)
        default: return "image/\(ext)"
        }
    }

    private static func mimeType(for format: ImageFormat) -> String {
        switch format {
        case .JPEG: return "image/jpeg"
        case .PNG: return "image/png"
        case .GIF: return "image/gif"
        default: return "image/png"
        }
    }
}

// MARK: - Session tracking

private struct LoadToken: Hashable {
    let id: ObjectIdentifier
    init(_ task: WKURLSchemeTask) {
        id = ObjectIdentifier(task as AnyObject)
    }
}

private actor LoadSessionStore {
    private var active: Set<ObjectIdentifier> = []
    private var downloads: [ObjectIdentifier: DownloadTask] = [:]

    func begin(_ token: LoadToken) {
        active.insert(token.id)
    }

    func bind(_ download: DownloadTask?, to token: LoadToken) {
        guard let download else { return }
        guard active.contains(token.id) else {
            download.cancel()
            return
        }
        downloads[token.id] = download
    }

    func isActive(_ token: LoadToken) -> Bool {
        active.contains(token.id)
    }

    func end(_ token: LoadToken) {
        active.remove(token.id)
        downloads.removeValue(forKey: token.id)
    }

    func abort(_ token: LoadToken) -> DownloadTask? {
        active.remove(token.id)
        return downloads.removeValue(forKey: token.id)
    }
}
