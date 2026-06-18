import Combine
import Foundation

// MARK: - AppTabRouter

/// Shared tab selection so deep views can switch main tabs (e.g. Profile → Plants).
@MainActor
final class AppTabRouter: ObservableObject {
    static let shared = AppTabRouter()

    enum Tab: Int {
        case home = 0
        case plants = 1
        case post = 2
        case messages = 3
        case profile = 4
    }

    @Published var selectedTab: Tab = .home

    /// Set by the post confirmation screen; HomeView consumes this to open the new post.
    @Published var pendingHomePostID: String?

    private init() {}

    /// Resets main-tab navigation to the default Home tab.
    func resetToHome() {
        selectedTab = .home
        pendingHomePostID = nil
    }

    func openPlants() {
        selectedTab = .plants
    }

    func openHomePost(postId: String) {
        pendingHomePostID = postId
        selectedTab = .home
    }

    func clearPendingHomePost() {
        pendingHomePostID = nil
    }
}
