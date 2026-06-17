import Foundation

/// Wipes all on-device user content. Called on logout and when no valid session exists.
@MainActor
enum LocalAppDataStore {
    static func clearAll() {
        AuthTokenStore.shared.clear()
        LocalAuthUserStore.shared.clear()
        LocalFeedStore.shared.clearAll()
        LocalChatStore.shared.clearAll()
        FollowStore.shared.clearAll()
        SavedPostsStore.shared.clearAll()
        LocalCommentStore.shared.clearAll()
        PlantCollectionStore.shared.clearAll()
        CommunityModerationStore.shared.clearAll()
        EntitlementStore.shared.clearLocalState()
        PushNotificationPreferencesStore.shared.clearAll()
        DeviceTokenStore.shared.clear()
        GardenFeedStore.shared.clearUserContent()
    }
}
