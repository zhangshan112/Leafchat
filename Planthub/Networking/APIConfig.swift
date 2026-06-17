import Foundation

enum APIConfig {
    static let baseURL = URL(string: "https://api.leaveschat.com")!

    static let defaultTimeout: TimeInterval = 30

    #if DEBUG
    static let isNetworkLoggingEnabled = true
    #else
    static let isNetworkLoggingEnabled = false
    #endif
}
