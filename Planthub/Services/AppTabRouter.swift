import Combine
import Foundation

// MARK: - AppTabRouter

/// Shared tab selection so deep views can switch main tabs (e.g. Profile → Plants).
@MainActor
final class AppTabRouter: ObservableObject {
    static let shared = AppTabRouter()

    enum Tab: Int {
        case identify  = 0
        case myGarden  = 1
        case discover  = 2
        case messages  = 3
        case profile   = 4
    }

    @Published var selectedTab: Tab = .identify

    /// Set by the post confirmation screen; DiscoverView consumes this to open the new post.
    @Published var pendingHomePostID: String?
    @Published var shouldOpenPlantEncyclopedia = false

    private init() {}

    /// Resets main-tab navigation to the primary Identify tab.
    func resetToHome() {
        selectedTab = .identify
        pendingHomePostID = nil
    }

    /// Navigates to My Garden tab (plant collection + encyclopedia).
    func openPlants() {
        selectedTab = .myGarden
    }

    /// Navigates to My Garden and asks it to present the encyclopedia sheet.
    func openPlantEncyclopedia() {
        shouldOpenPlantEncyclopedia = true
        selectedTab = .myGarden
    }

    func clearPlantEncyclopediaRequest() {
        shouldOpenPlantEncyclopedia = false
    }

    /// Navigates to Discover tab and queues a post to open.
    func openHomePost(postId: String) {
        pendingHomePostID = postId
        selectedTab = .discover
    }

    func clearPendingHomePost() {
        pendingHomePostID = nil
    }
}
