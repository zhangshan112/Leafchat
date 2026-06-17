import Combine
import Foundation

/// Local following relationship store keyed by current signed-in user.
@MainActor
final class FollowStore: ObservableObject {
    static let shared = FollowStore()

    @Published private(set) var followingUserIDs: Set<String> = []

    private var activeUserID: String?
    private let defaultsKeyPrefix = "com.planthub.following.v1"
    private let mockSeedKeyPrefix = "com.planthub.following.seededMockChat.v1"

    private init() {
        if let authUser = UserSessionStore.shared.authUser {
            syncCurrentUser(authUser)
        }
    }

    func syncCurrentUser(_ user: AuthUser) {
        let userID = user.id.uuidString

        if activeUserID != userID {
            activeUserID = userID
            loadFollowing(for: userID)
        }

        ensureMockChatUsersFollowedIfNeeded()
    }

    func isFollowing(_ userID: String) -> Bool {
        followingUserIDs.contains(userID)
    }

    func toggleFollow(userID: String) {
        guard !userID.isEmpty else { return }

        if followingUserIDs.contains(userID) {
            followingUserIDs.remove(userID)
        } else {
            followingUserIDs.insert(userID)
        }

        persist()
    }

    func clearAll() {
        followingUserIDs = []
        activeUserID = nil

        for key in UserDefaults.standard.dictionaryRepresentation().keys
            where key.hasPrefix(defaultsKeyPrefix) || key.hasPrefix(mockSeedKeyPrefix) {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Private

    private var currentDefaultsKey: String? {
        guard let activeUserID else { return nil }
        return "\(defaultsKeyPrefix).\(activeUserID)"
    }

    private func loadFollowing(for userID: String) {
        let key = "\(defaultsKeyPrefix).\(userID)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let ids = try? JSONDecoder().decode([String].self, from: data) else {
            followingUserIDs = []
            return
        }

        followingUserIDs = Set(ids)
    }

    private func persist() {
        guard let key = currentDefaultsKey else { return }
        let ids = Array(followingUserIDs).sorted()
        guard let data = try? JSONEncoder().encode(ids) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private var currentMockSeedKey: String? {
        guard let activeUserID else { return nil }
        return "\(mockSeedKeyPrefix).\(activeUserID)"
    }

    private func ensureMockChatUsersFollowedIfNeeded() {
        guard let seedKey = currentMockSeedKey else { return }
        guard UserDefaults.standard.bool(forKey: seedKey) == false else { return }

        let requiredUserIDs = Set(LocalChatStore.mockChatCounterpartUserIDs())
        if !requiredUserIDs.isEmpty {
            followingUserIDs.formUnion(requiredUserIDs)
            persist()
        }
        UserDefaults.standard.set(true, forKey: seedKey)
    }
}
