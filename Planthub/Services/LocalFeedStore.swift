import Foundation
import UIKit

// MARK: - Persistence models

private struct PersistedFeedSnapshot: Codable {
    var posts: [PersistedSpecimenPost]
}

private struct PersistedSpecimenPost: Codable, Identifiable {
    let id: String
    let plantName: String
    let scientificName: String?
    let caption: String
    let imageFilename: String?
    let status: PlantStatus
    let plot: GardenPlot
    let author: PersistedAuthor
    let createdAt: Date
    var likeCount: Int
    var commentCount: Int
    var isLiked: Bool
    let stature: String
    var plantTags: [String]
}

private struct PersistedAuthor: Codable {
    let id: String
    let username: String
    let avatarURLString: String?
}

// MARK: - LocalFeedStore

/// Local-only persistence for user-published feed posts.
@MainActor
final class LocalFeedStore {
    static let shared = LocalFeedStore()

    private var persistedPosts: [PersistedSpecimenPost] = []
    private let defaultsKey = "com.planthub.localFeed.posts.v1"
    private let fileManager = FileManager.default

    private init() {
        load()
    }

    func loadPosts() -> [SpecimenPost] {
        persistedPosts.map { $0.toSpecimenPost(imagesDirectory: imagesDirectory) }
    }

    func save(_ post: SpecimenPost, coverImage: UIImage?) {
        var imageFilename: String?

        if let coverImage {
            imageFilename = saveImage(coverImage, postID: post.id)
        }

        let persisted = PersistedSpecimenPost(
            post: post,
            imageFilename: imageFilename
        )

        persistedPosts.removeAll { $0.id == post.id }
        persistedPosts.insert(persisted, at: 0)
        persist()
    }

    func update(_ post: SpecimenPost) {
        guard let index = persistedPosts.firstIndex(where: { $0.id == post.id }) else { return }

        let existingFilename = persistedPosts[index].imageFilename
        persistedPosts[index] = PersistedSpecimenPost(
            post: post,
            imageFilename: existingFilename
        )
        persist()
    }

    func contains(postID: String) -> Bool {
        persistedPosts.contains { $0.id == postID }
    }

    func clearAll() {
        persistedPosts = []
        UserDefaults.standard.removeObject(forKey: defaultsKey)

        let directory = imagesDirectory
        if fileManager.fileExists(atPath: directory.path) {
            try? fileManager.removeItem(at: directory)
        }
    }

    // MARK: Private

    private var imagesDirectory: URL {
        let base = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("FeedImages", isDirectory: true)

        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory
    }

    private func saveImage(_ image: UIImage, postID: String) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }

        let filename = "\(postID).jpg"
        let url = imagesDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: url, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let snapshot = try? JSONDecoder().decode(PersistedFeedSnapshot.self, from: data)
        else {
            return
        }

        persistedPosts = snapshot.posts
    }

    private func persist() {
        let snapshot = PersistedFeedSnapshot(posts: persistedPosts)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

// MARK: - Mapping

private extension PersistedSpecimenPost {
    init(post: SpecimenPost, imageFilename: String?) {
        id = post.id
        plantName = post.plantName
        scientificName = post.scientificName
        caption = post.caption
        self.imageFilename = imageFilename
        status = post.status
        plot = post.plot
        author = PersistedAuthor(
            id: post.author.id,
            username: post.author.username,
            avatarURLString: post.author.avatarUrlString
        )
        createdAt = post.createdAt
        likeCount = post.likeCount
        commentCount = post.commentCount
        isLiked = post.isLiked
        stature = post.stature.persistenceKey
        plantTags = post.plantTags
    }

    func toSpecimenPost(imagesDirectory: URL) -> SpecimenPost {
        let localImage: UIImage? = {
            guard let imageFilename else { return nil }
            let url = imagesDirectory.appendingPathComponent(imageFilename)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return UIImage(contentsOfFile: url.path)
        }()

        return SpecimenPost(
            id: id,
            plantName: plantName,
            scientificName: scientificName,
            caption: caption,
            localImage: localImage,
            imageAssetName: nil,
            status: status,
            plot: plot,
            author: PostCardUser(
                id: author.id,
                username: author.username,
                avatarUrlString: author.avatarURLString
            ),
            createdAt: createdAt,
            likeCount: likeCount,
            commentCount: commentCount,
            isLiked: isLiked,
            stature: SpecimenStature(persistenceKey: stature),
            plantTags: plantTags
        )
    }
}

private extension SpecimenStature {
    var persistenceKey: String {
        switch self {
        case .sprout: return "sprout"
        case .bloom:  return "bloom"
        case .vine:   return "vine"
        }
    }

    init(persistenceKey: String) {
        switch persistenceKey {
        case "bloom": self = .bloom
        case "vine":  self = .vine
        default:      self = .sprout
        }
    }
}
