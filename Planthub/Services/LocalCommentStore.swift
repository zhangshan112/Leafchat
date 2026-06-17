import Foundation

// MARK: - Persistence models

struct PersistedCommentEntry: Codable, Identifiable, Equatable {
    let id: String
    let postId: String
    let parentCommentId: String?
    let userId: String
    let username: String
    let avatarURLString: String?
    let content: String
    let createdAt: Date
    var likeCount: Int
    var isLiked: Bool
}

private struct PersistedCommentSnapshot: Codable {
    var entries: [PersistedCommentEntry]
}

// MARK: - LocalCommentStore

/// Local-only persistence for user-authored post comments and replies.
@MainActor
final class LocalCommentStore {
    static let shared = LocalCommentStore()

    private var entries: [PersistedCommentEntry] = []
    private let defaultsKey = "com.planthub.localComments.v1"

    private init() {
        load()
    }

    func topLevelComments(for postId: String) -> [PersistedCommentEntry] {
        entries
            .filter { $0.postId == postId && $0.parentCommentId == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func replies(for postId: String, parentCommentId: String) -> [PersistedCommentEntry] {
        entries
            .filter { $0.postId == postId && $0.parentCommentId == parentCommentId }
            .sorted { $0.createdAt < $1.createdAt }
    }

    @discardableResult
    func saveTopLevelComment(
        postId: String,
        author: CommentAuthorSnapshot,
        content: String
    ) -> PersistedCommentEntry {
        let entry = PersistedCommentEntry(
            id: UUID().uuidString,
            postId: postId,
            parentCommentId: nil,
            userId: author.userId,
            username: author.username,
            avatarURLString: author.avatarURLString,
            content: content,
            createdAt: Date(),
            likeCount: 0,
            isLiked: false
        )
        entries.insert(entry, at: 0)
        persist()
        return entry
    }

    @discardableResult
    func saveReply(
        postId: String,
        parentCommentId: String,
        author: CommentAuthorSnapshot,
        content: String
    ) -> PersistedCommentEntry {
        let entry = PersistedCommentEntry(
            id: UUID().uuidString,
            postId: postId,
            parentCommentId: parentCommentId,
            userId: author.userId,
            username: author.username,
            avatarURLString: author.avatarURLString,
            content: content,
            createdAt: Date(),
            likeCount: 0,
            isLiked: false
        )
        entries.append(entry)
        persist()
        return entry
    }

    func clearAll() {
        entries = []
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}

// MARK: - Mapping

extension PersistedCommentEntry {
    func toCommentCardData() -> CommentCardData {
        CommentCardData(
            id: id,
            userId: userId,
            username: username,
            avatarURL: avatarURLString.flatMap { URL(string: $0) },
            content: content,
            createdAt: createdAt,
            likeCount: likeCount,
            isLiked: isLiked
        )
    }
}

// MARK: - Private

private extension LocalCommentStore {
    func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let snapshot = try? JSONDecoder().decode(PersistedCommentSnapshot.self, from: data)
        else { return }

        entries = snapshot.entries
    }

    func persist() {
        let snapshot = PersistedCommentSnapshot(entries: entries)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

// MARK: - Comment author

struct CommentAuthorSnapshot: Equatable {
    let userId: String
    let username: String
    let avatarURLString: String?

    var avatarURL: URL? {
        avatarURLString.flatMap { URL(string: $0) }
    }
}

extension UserSessionStore {
    var commentAuthor: CommentAuthorSnapshot? {
        guard let authUser else { return nil }

        return CommentAuthorSnapshot(
            userId: authUser.id.uuidString,
            username: authUser.username,
            avatarURLString: authUser.avatarUrlString
        )
    }
}
