import Combine
import SwiftUI

// MARK: - Garden feed store

/// Shared, observable source of truth for the garden feed.
///
/// Both `HomeView` (display) and `PostView` (create) read from and write to this
/// store, so a freshly published specimen appears at the top of the home feed
/// immediately — keeping the two screens in sync.
///
/// User-published posts are persisted locally via `LocalFeedStore` and survive
/// app relaunches. Seeded community mock posts remain in-memory only.
@MainActor
final class GardenFeedStore: ObservableObject {

    static let shared = GardenFeedStore()

    @Published private(set) var posts: [SpecimenPost]

    /// The signed-in author used for posts created in this session.
    @Published private(set) var currentUser: PostCardUser?

    private let localFeedStore = LocalFeedStore.shared
    private let moderationStore = CommunityModerationStore.shared
    private let savedPostsStore = SavedPostsStore.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        posts = Self.mergePosts(
            userPosts: localFeedStore.loadPosts(),
            communityPosts: GardenHomeMockData.posts
        )
        applySavedStateToPosts()

        moderationStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Derived data

    var visiblePosts: [SpecimenPost] {
        posts.filter { moderationStore.isPostVisible($0) }
    }

    var savedVisiblePosts: [SpecimenPost] {
        visiblePosts.filter(\.isSaved)
    }

    var pulse: GardenPulse {
        GardenHomeMockData.pulse(for: visiblePosts)
    }

    var trendingTags: [String] {
        GardenHomeMockData.trendingTags(in: visiblePosts)
    }

    func postCount(for plot: GardenPlot) -> Int {
        GardenHomeMockData.postCount(for: plot, in: visiblePosts)
    }

    func syncCurrentUser(from authUser: AuthUser) {
        currentUser = authUser.postCardUser()
        savedPostsStore.syncCurrentUser(authUser)
        applySavedStateToPosts()
    }

    func clearUserContent() {
        currentUser = nil
        posts = GardenHomeMockData.posts
        applySavedStateToPosts()
    }

    // MARK: - Mutations

    func toggleLike(_ id: String) {
        guard let index = posts.firstIndex(where: { $0.id == id }) else { return }
        posts[index].isLiked.toggle()
        posts[index].likeCount += posts[index].isLiked ? 1 : -1

        if localFeedStore.contains(postID: id) {
            localFeedStore.update(posts[index])
        }
    }

    func isSaved(_ id: String) -> Bool {
        savedPostsStore.isSaved(id)
    }

    func toggleSaved(_ id: String) {
        let nextValue = !savedPostsStore.isSaved(id)
        savedPostsStore.setSaved(nextValue, postID: id)
        applySavedState(postID: id, isSaved: nextValue)
    }

    /// Build a specimen post from create-flow input, persist it locally, and insert at the top of the feed.
    @discardableResult
    func publish(
        plantName: String,
        scientificName: String?,
        caption: String,
        status: PlantStatus,
        plot: GardenPlot,
        plantTags: [String],
        coverImage: UIImage?
    ) -> SpecimenPost? {
        guard let currentUser else { return nil }

        let trimmedScientific = scientificName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let post = SpecimenPost(
            id: UUID().uuidString,
            plantName: plantName.trimmingCharacters(in: .whitespacesAndNewlines),
            scientificName: (trimmedScientific?.isEmpty == false) ? trimmedScientific : nil,
            caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
            localImage: coverImage,
            status: status,
            plot: plot,
            author: currentUser,
            createdAt: Date(),
            likeCount: 0,
            commentCount: 0,
            isLiked: false,
            isSaved: false,
            stature: Self.statures[posts.count % Self.statures.count],
            plantTags: plantTags
        )

        localFeedStore.save(post, coverImage: coverImage)
        posts.insert(post, at: 0)
        return post
    }

    /// Reload seeded community posts while keeping locally persisted user posts.
    func reload() {
        posts = Self.mergePosts(
            userPosts: localFeedStore.loadPosts(),
            communityPosts: GardenHomeMockData.posts
        )
        applySavedStateToPosts()
    }

    // MARK: Private

    private static func mergePosts(
        userPosts: [SpecimenPost],
        communityPosts: [SpecimenPost]
    ) -> [SpecimenPost] {
        let userIDs = Set(userPosts.map(\.id))
        let filteredCommunity = communityPosts.filter { !userIDs.contains($0.id) }
        return userPosts + filteredCommunity
    }

    private func applySavedStateToPosts() {
        for index in posts.indices {
            posts[index].isSaved = savedPostsStore.isSaved(posts[index].id)
        }
    }

    private func applySavedState(postID: String, isSaved: Bool) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index].isSaved = isSaved
    }

    private static let statures: [SpecimenStature] = [.sprout, .bloom, .vine]
}
