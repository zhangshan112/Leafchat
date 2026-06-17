import UIKit

// MARK: - PostDraft

/// A transient package carrying identified plant data from the AI scanner to PostView.
/// Identified by UUID so `onChange(of:)` reliably fires even if content is unchanged.
struct PostDraft: Equatable {
    let id = UUID()
    let plantName: String
    let scientificName: String?
    let images: [UIImage]

    static func == (lhs: PostDraft, rhs: PostDraft) -> Bool { lhs.id == rhs.id }
}

// MARK: - PostDraftStore

/// Singleton that bridges PlantIdentificationView → MainTabView → PostView.
///
/// Flow:
/// 1. `PlantIdentificationView` calls `set(...)` after identification succeeds.
/// 2. `MainTabView` observes `pending` becoming non-nil and switches to the Post tab.
/// 3. `PostView` observes `pending` and calls `consume()` to apply the prefill.
@Observable
final class PostDraftStore {

    static let shared = PostDraftStore()
    private init() {}

    /// Non-nil while a prefill is waiting to be consumed by PostView.
    private(set) var pending: PostDraft? = nil

    /// Write a new draft. Triggers tab switch in MainTabView, then prefill in PostView.
    func set(plantName: String, scientificName: String?, images: [UIImage]) {
        let trimmedSci = scientificName.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
        pending = PostDraft(plantName: plantName, scientificName: trimmedSci, images: images)
    }

    /// Read and clear the pending draft. Returns nil if nothing is waiting.
    func consume() -> PostDraft? {
        guard let draft = pending else { return nil }
        pending = nil
        return draft
    }
}
