import Foundation
import WebKit

class CoreScriptInteractor: NSObject, JSEventDelegate {
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

        guard let callbackData = try? JSONSerialization.data(withJSONObject: callbackInfo, options: []),
              let callbackJsonString = String(data: callbackData, encoding: .utf8) else {
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
}

