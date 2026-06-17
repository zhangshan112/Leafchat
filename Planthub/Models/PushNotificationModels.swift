import Foundation

struct RegisterPushTokenRequest: Codable, Sendable {
    let token: String
    let platform: String
    let preferences: PushNotificationPreferencesPayload

    init(token: String, preferences: PushNotificationPreferences) {
        self.token = token
        self.platform = "ios"
        self.preferences = PushNotificationPreferencesPayload(from: preferences)
    }
}

enum PushNotificationCategory: String, Sendable {
    case like
    case comment
    case follow
    case message
}

/// Parsed remote notification payload for future deep-link routing.
struct PushNotificationPayload: Sendable {
    let category: PushNotificationCategory?
    let targetId: String?

    init(userInfo: [AnyHashable: Any]) {
        category = (userInfo["category"] as? String).flatMap(PushNotificationCategory.init(rawValue:))
        targetId = userInfo["targetId"] as? String
    }
}
