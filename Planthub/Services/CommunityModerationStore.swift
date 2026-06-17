import Combine
import Foundation

// MARK: - CommunityModerationStore

/// Local-only moderation state for reports and blocks until backend APIs ship.
@MainActor
final class CommunityModerationStore: ObservableObject {
    static let shared = CommunityModerationStore()

    @Published private(set) var blockedUsers: [BlockedUserRecord] = []

    private var hiddenPostIDs = Set<String>()
    private var suppressedUserIDs = Set<String>()
    private var reports: [StoredCommunityReport] = []

    private let defaultsKey = "com.planthub.communityModeration.v1"

    private init() {
        load()
    }

    // MARK: - Visibility

    func isPostVisible(_ post: SpecimenPost) -> Bool {
        isPostSuppressed(postId: post.id, authorId: post.author.id) == false
    }

    func isPostHidden(_ postId: String) -> Bool {
        hiddenPostIDs.contains(postId)
    }

    func isPostSuppressed(postId: String, authorId: String) -> Bool {
        isPostHidden(postId) || isUserSuppressed(authorId)
    }

    func isUserBlocked(_ userId: String) -> Bool {
        blockedUsers.contains { $0.id == userId }
    }

    func isUserSuppressed(_ userId: String) -> Bool {
        isUserBlocked(userId) || suppressedUserIDs.contains(userId)
    }

    // MARK: - Block

    func blockUser(id: String, username: String) {
        guard !isUserBlocked(id) else { return }

        blockedUsers.insert(
            BlockedUserRecord(id: id, username: username, blockedAt: Date()),
            at: 0
        )
        suppressedUserIDs.remove(id)
        persist()
    }

    func unblockUser(id: String) {
        blockedUsers.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Report

    @discardableResult
    func reportPost(
        id: String,
        authorId: String,
        authorUsername: String,
        submission: CommunityReportSubmission
    ) -> StoredCommunityReport {
        hiddenPostIDs.insert(id)
        return saveReport(
            target: .post(id: id, authorId: authorId, authorUsername: authorUsername),
            submission: submission
        )
    }

    @discardableResult
    func reportUser(
        id: String,
        username: String,
        submission: CommunityReportSubmission
    ) -> StoredCommunityReport {
        suppressedUserIDs.insert(id)
        return saveReport(
            target: .user(id: id, username: username),
            submission: submission
        )
    }

    // MARK: - Private

    @discardableResult
    private func saveReport(
        target: CommunityReportTarget,
        submission: CommunityReportSubmission
    ) -> StoredCommunityReport {
        let record = StoredCommunityReport(
            id: UUID().uuidString,
            target: target,
            reason: submission.reason,
            detail: submission.resolvedDetail,
            createdAt: Date()
        )
        reports.insert(record, at: 0)
        persist()
        return record
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let snapshot = try? JSONDecoder().decode(CommunityModerationSnapshot.self, from: data)
        else { return }

        blockedUsers = snapshot.blockedUsers
        hiddenPostIDs = Set(snapshot.hiddenPostIDs)
        suppressedUserIDs = Set(snapshot.suppressedUserIDs)
        reports = snapshot.reports
    }

    func clearAll() {
        blockedUsers = []
        hiddenPostIDs = []
        suppressedUserIDs = []
        reports = []
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    private func persist() {
        let snapshot = CommunityModerationSnapshot(
            blockedUsers: blockedUsers,
            hiddenPostIDs: Array(hiddenPostIDs),
            suppressedUserIDs: Array(suppressedUserIDs),
            reports: reports
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

// MARK: - Persistence snapshot

private struct CommunityModerationSnapshot: Codable {
    var blockedUsers: [BlockedUserRecord]
    var hiddenPostIDs: [String]
    var suppressedUserIDs: [String]
    var reports: [StoredCommunityReport]
}
