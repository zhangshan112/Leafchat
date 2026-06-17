import Foundation

struct PushNotificationPreferences: Codable, Equatable, Sendable {
    var likes: Bool = true
    var comments: Bool = true
    var follows: Bool = true
    var messages: Bool = true
}

struct PushNotificationPreferencesPayload: Codable, Sendable {
    let likes: Bool
    let comments: Bool
    let follows: Bool
    let messages: Bool

    init(from preferences: PushNotificationPreferences) {
        likes = preferences.likes
        comments = preferences.comments
        follows = preferences.follows
        messages = preferences.messages
    }
}

/// Local notification preference toggles until the backend preference API is available.
final class PushNotificationPreferencesStore: @unchecked Sendable {
    static let shared = PushNotificationPreferencesStore()

    private let defaultsKey = "com.planthub.pushNotificationPreferences"

    private init() {}

    var preferences: PushNotificationPreferences {
        get {
            guard let data = UserDefaults.standard.data(forKey: defaultsKey),
                  let decoded = try? JSONDecoder().decode(PushNotificationPreferences.self, from: data)
            else {
                return PushNotificationPreferences()
            }

            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    func clearAll() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
