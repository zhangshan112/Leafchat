import Combine
import Foundation
import SwiftUI

// MARK: - UserSessionStore

enum SessionRestoreResult {
    case restored
    case unauthenticated
}

/// Cached authenticated user profile shared across Profile, Home, and Feed.
@MainActor
final class UserSessionStore: ObservableObject {
    static let shared = UserSessionStore()

    @Published private(set) var authUser: AuthUser?

    private init() {
        let hasToken = AuthTokenStore.shared.token != nil

        if hasToken, let user = LocalAuthUserStore.shared.load() {
            // Avoid cross-store side effects during singleton initialization.
            authUser = user
        }
    }

    func apply(_ user: AuthUser) {
        apply(user, persist: true)
    }

    private func apply(_ user: AuthUser, persist: Bool) {
        authUser = user
        if persist {
            LocalAuthUserStore.shared.save(user)
        }
        syncDependentStores(with: user)
    }

    func clear() {
        authUser = nil
        LocalAppDataStore.clearAll()
    }

    /// Restores a session only when both session token and local profile exist.
    func restoreSession() async -> SessionRestoreResult {
        guard AuthTokenStore.shared.token != nil else {
            clear()
            return .unauthenticated
        }

        guard let restoredUser = authUser ?? LocalAuthUserStore.shared.load() else {
            AuthTokenStore.shared.clear()
            clear()
            return .unauthenticated
        }

        authUser = restoredUser
        syncDependentStores(with: restoredUser)
        return .restored
    }

    @discardableResult
    func refresh(using authService: AuthAPIService = AuthAPIService()) async throws -> AuthUser {
        let user = try await authService.currentUser()
        apply(user)
        return user
    }

    private func syncDependentStores(with user: AuthUser) {
        GardenFeedStore.shared.syncCurrentUser(from: user)
        LocalChatStore.shared.syncCurrentUser(user)
        FollowStore.shared.syncCurrentUser(user)
        SavedPostsStore.shared.syncCurrentUser(user)
        PlantCollectionStore.shared.reload(for: user.id.uuidString)
        EntitlementStore.shared.reload(for: user.id.uuidString)
    }
}

// MARK: - AuthUser mapping

extension AuthUser {
    var avatarUrlString: String? {
        guard let avatarUrl, !avatarUrl.isEmpty else { return nil }
        return avatarUrl
    }

    var displayName: String {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedName.isEmpty ? username : trimmedName
    }

    var profileHeaderData: ProfileHeaderData {
        ProfileHeaderData(
            id: id.uuidString,
            username: displayName,
            avatarUrlString: avatarUrlString,
            bio: bio ?? "",
            country: country ?? "",
            postsCount: 0,
            plantsCount: 0,
            followersCount: 0,
            followingCount: 0,
            isFollowing: false
        )
    }

    func postCardUser() -> PostCardUser {
        PostCardUser(
            id: id.uuidString,
            username: displayName,
            avatarUrlString: avatarUrlString
        )
    }
}
