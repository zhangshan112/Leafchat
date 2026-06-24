import SwiftUI

// MARK: - EmptyStateView

/// Unified empty-state layout used across all pages.
/// Shows an SF Symbol illustration, a bold title, a secondary description,
/// and an optional primary action button.
struct EmptyStateView: View {

    let systemImage: String
    let title: String
    let description: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 56))
                .foregroundStyle(Color.secondaryBlue)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, action: action)
                    .frame(maxWidth: 240)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preset configurations

extension EmptyStateView {

    /// "No posts yet. Follow plant lovers to see their posts." + Discover Users
    static func noFollowingPosts(action: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            systemImage: "tree",
            title: "No posts yet.",
            description: "Follow plant lovers to see their posts.",
            actionTitle: "Discover Users",
            action: action
        )
    }

    /// "No results found. Try another keyword."
    static var searchNoResults: EmptyStateView {
        EmptyStateView(
            systemImage: "magnifyingglass",
            title: "No results found.",
            description: "Try another keyword."
        )
    }

    /// "No notifications yet."
    static var noNotifications: EmptyStateView {
        EmptyStateView(
            systemImage: "bell",
            title: "No notifications yet.",
            description: "We'll let you know when something happens."
        )
    }

    /// "No conversations yet."
    static var noChats: EmptyStateView {
        EmptyStateView(
            systemImage: "message",
            title: "No conversations yet.",
            description: "Start chatting with plant lovers."
        )
    }

    /// "No posts yet. Share your first plant moment."
    static var noPosts: EmptyStateView {
        EmptyStateView(
            systemImage: "photo.on.rectangle.angled",
            title: "No posts yet.",
            description: "Share your first plant moment."
        )
    }

    /// "No plants yet. Add your first plant to your collection."
    static var noPlants: EmptyStateView {
        EmptyStateView(
            systemImage: "tree.fill",
            title: "No plants yet.",
            description: "Add your first plant to your collection."
        )
    }
}

// MARK: - Preview

#Preview {
    TabView {
        EmptyStateView.noFollowingPosts(action: {})
            .tabItem { Label("Feed", systemImage: "house") }

        EmptyStateView.searchNoResults
            .tabItem { Label("Search", systemImage: "magnifyingglass") }

        EmptyStateView.noPlants
            .tabItem { Label("Plants", systemImage: "tree") }
    }
}
