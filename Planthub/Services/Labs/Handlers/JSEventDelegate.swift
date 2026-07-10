import Foundation

public protocol JSEventDelegate {
    func handleJSCall(params: [String: Any], callbackID: String)

    func supportedActions() -> [Int]
}

