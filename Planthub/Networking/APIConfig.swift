import Foundation

enum APIConfig {
    #if DEBUG
    static let baseURL = URL(string: "https://api.leaveschat.com")!
    #else
    static let baseURL = URL(string: "https://api.leaveschat.com")!
    #endif

    static let defaultTimeout: TimeInterval = 30

    #if DEBUG
    static let isNetworkLoggingEnabled = true
    #else
    static let isNetworkLoggingEnabled = false
    #endif
}
