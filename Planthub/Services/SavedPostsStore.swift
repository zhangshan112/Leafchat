import Foundation
import Combine

/// Local saved-post relationship store keyed by current signed-in user.
@MainActor
final class SavedPostsStore: ObservableObject {
    static let shared = SavedPostsStore()

    @Published private(set) var savedPostIDs: Set<String> = []

    private var activeUserID: String?
    private let defaultsKeyPrefix = "com.planthub.savedPosts.v1"
    private let seedKeyPrefix = "com.planthub.savedPosts.seededDefault.v1"

    private init() {
        if let authUser = UserSessionStore.shared.authUser {
            syncCurrentUser(authUser)
        }
    }

    func syncCurrentUser(_ user: AuthUser) {
        let userID = user.id.uuidString
        if activeUserID != userID {
            activeUserID = userID
            loadSavedPosts(for: userID)
        }
        ensureDefaultMockSavedPostsIfNeeded()
    }

    func isSaved(_ postID: String) -> Bool {
        savedPostIDs.contains(postID)
    }

    func setSaved(_ isSaved: Bool, postID: String) {
        guard !postID.isEmpty else { return }
        if isSaved {
            savedPostIDs.insert(postID)
        } else {
            savedPostIDs.remove(postID)
        }
        persist()
    }

    func toggleSaved(postID: String) {
        setSaved(!isSaved(postID), postID: postID)
    }

    func clearAll() {
        savedPostIDs = []
        activeUserID = nil

        for key in UserDefaults.standard.dictionaryRepresentation().keys
            where key.hasPrefix(defaultsKeyPrefix) || key.hasPrefix(seedKeyPrefix) {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Private

    private var currentDefaultsKey: String? {
        guard let activeUserID else { return nil }
        return "\(defaultsKeyPrefix).\(activeUserID)"
    }

    private var currentSeedKey: String? {
        guard let activeUserID else { return nil }
        return "\(seedKeyPrefix).\(activeUserID)"
    }

    private func loadSavedPosts(for userID: String) {
        let key = "\(defaultsKeyPrefix).\(userID)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let ids = try? JSONDecoder().decode([String].self, from: data) else {
            savedPostIDs = []
            return
        }

        savedPostIDs = Set(ids)
    }

    private func persist() {
        guard let key = currentDefaultsKey else { return }
        let ids = Array(savedPostIDs).sorted()
        guard let data = try? JSONEncoder().encode(ids) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func ensureDefaultMockSavedPostsIfNeeded() {
        guard let seedKey = currentSeedKey else { return }
        guard UserDefaults.standard.bool(forKey: seedKey) == false else { return }

        let defaultIDs = Self.defaultMockSavedPostIDs()
        if !defaultIDs.isEmpty {
            savedPostIDs.formUnion(defaultIDs)
            persist()
        }

        UserDefaults.standard.set(true, forKey: seedKey)
    }

    private static func defaultMockSavedPostIDs(limit: Int = 3) -> [String] {
        let allIDs = Set(GardenHomeMockData.posts.map(\.id))
        let preferred = ["nl2", "sc2", "er3", "bi2"].filter { allIDs.contains($0) }

        if preferred.count >= limit {
            return Array(preferred.prefix(limit))
        }

        var ordered = preferred
        for post in GardenHomeMockData.posts where !ordered.contains(post.id) {
            ordered.append(post.id)
            if ordered.count == limit { break }
        }
        return ordered
    }
}
