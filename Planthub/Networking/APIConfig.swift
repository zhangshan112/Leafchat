import Foundation

enum APIConfig {
    #if DEBUG
    static let baseURL = URL(string: "https://api.leaveschat.com")!
    #else
    static let baseURL = URL(string: "https://api.leaveschat.com")!
    #endif

    static let defaultTimeout: TimeInterval = 30
}
