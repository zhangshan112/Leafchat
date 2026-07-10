import Foundation
import WebKit
import os.log

class CoreScriptInteractor: NSObject, JSEventDelegate {
    private static let bridgeLog = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "LabsModule",
        category: "JSBridge"
    )

    weak var webView: WKWebView?
    
    init(webView: WKWebView) {
        self.webView = webView
    }
    
    
    func handleJSCall(params: [String: Any], callbackID: String) {
        sendError(callbackID: callbackID, message: "Method not implemented")
    }
    
    func supportedActions() -> [Int] {
        return []
    }
    
    func sendCallback(callbackID: String, withResult result: [String: Any]) {
        guard !callbackID.isEmpty else { return }
        guard let webView else { return }

        let callbackInfo: [String: Any] = [
            "callbackID": callbackID,
            "result": result
        ]
        Self.logNativeCallbackPayload(callbackInfo)

        guard let callbackData = try? JSONSerialization.data(withJSONObject: callbackInfo, options: []),
              let callbackJsonString = String(data: callbackData, encoding: .utf8) else {
            os_log(
                "[JSBridge] onNativeCallback 无法序列化 → callbackID=%{public}@ result=%{public}@",
                log: Self.bridgeLog, type: .error, callbackID, String(describing: result)
            )
            return
        }

        let jsCode = "window.onNativeCallback('\(callbackJsonString.replacingOccurrences(of: "'", with: "\\'"))')"

        DispatchQueue.main.async {
            webView.evaluateJavaScript(jsCode, completionHandler: nil)
        }
    }
    

    func sendError(callbackID: String, message: String) {
        sendCallback(callbackID: callbackID, withResult: ["error": message])
    }

    static func replyUnknownMethod(on webView: WKWebView?, callbackID: String) {
        guard let webView, !callbackID.isEmpty else { return }
        CoreScriptInteractor(webView: webView).sendCallback(
            callbackID: callbackID,
            withResult: ["status": LabsBridgeAction.unsupportedCode]
        )
    }

    private static func logNativeCallbackPayload(_ callbackInfo: [String: Any]) {
        if JSONSerialization.isValidJSONObject(callbackInfo),
           let data = try? JSONSerialization.data(withJSONObject: callbackInfo, options: [.prettyPrinted, .sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            os_log("[JSBridge] onNativeCallback →\n%{public}@", log: Self.bridgeLog, type: .info, json)
        } else {
            os_log(
                "[JSBridge] onNativeCallback (非 JSON 可序列化) → %{public}@",
                log: Self.bridgeLog, type: .info, String(describing: callbackInfo)
            )
        }
    }
}

