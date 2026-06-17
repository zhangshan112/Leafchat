import Foundation

// MARK: - Report reasons

enum CommunityReportReason: String, CaseIterable, Identifiable, Codable {
    case spam
    case harassment
    case inappropriate
    case unsafeAdvice
    case copyright
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spam:
            return "Spam or misleading content"
        case .harassment:
            return "Harassment or hate speech"
        case .inappropriate:
            return "Inappropriate or offensive content"
        case .unsafeAdvice:
            return "Unsafe or dangerous plant advice"
        case .copyright:
            return "Copyright or stolen content"
        case .other:
            return "Other"
        }
    }
}

enum CommunityReportTarget: Codable, Equatable {
    case post(id: String, authorId: String, authorUsername: String)
    case user(id: String, username: String)
}

struct CommunityReportSubmission: Equatable {
    let reason: CommunityReportReason
    let customDetail: String

    var resolvedDetail: String {
        let trimmed = customDetail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard reason == .other else {
            return trimmed.isEmpty ? reason.title : "\(reason.title) — \(trimmed)"
        }
        return trimmed
    }
}

// MARK: - Persistence models

struct BlockedUserRecord: Codable, Identifiable, Hashable {
    let id: String
    let username: String
    let blockedAt: Date
}

struct StoredCommunityReport: Codable, Identifiable {
    let id: String
    let target: CommunityReportTarget
    let reason: CommunityReportReason
    let detail: String
    let createdAt: Date
}
