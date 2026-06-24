import SwiftUI
import UIKit

// MARK: - Search Tab

enum SearchTab: String, CaseIterable, Identifiable {
    case users = "Users"
    case plants = "Plants"
    case posts = "Posts"

    var id: String { rawValue }
}

// MARK: - SearchView

struct SearchView: View {
    let defaultTab: SearchTab

    @ObservedObject private var store = GardenFeedStore.shared
    @ObservedObject private var moderation = CommunityModerationStore.shared
    @ObservedObject private var session = UserSessionStore.shared
    @ObservedObject private var followStore = FollowStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SearchTab
    @State private var query = ""

    private let plantColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    init(defaultTab: SearchTab = .plants) {
        self.defaultTab = defaultTab
        _selectedTab = State(initialValue: defaultTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            tabBar
            Divider()
            content
        }
        .background(Color.phBackground)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if let authUser = session.authUser {
                followStore.syncCurrentUser(authUser)
            }
        }
    }

    // MARK: - Header

    private var searchHeader: some View {
        HStack(spacing: 8) {
            SearchBar(
                text: $query,
                placeholder: "Search plants, users...",
                autoFocus: true,
                onCancel: { dismiss() }
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Tabs

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(SearchTab.allCases) { tab in
                tabButton(tab)
            }
        }
    }

    private func tabButton(_ tab: SearchTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 0) {
                Text(tab.rawValue)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.primaryBlue : Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)

                Rectangle()
                    .fill(isSelected ? Color.primaryBlue : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .users:
            usersContent
        case .plants:
            plantsContent
        case .posts:
            postsContent
        }
    }

    private var usersContent: some View {
        Group {
            let results = filteredUsers
            if results.isEmpty {
                noResultsView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { user in
                            NavigationLink {
                                UserProfileView(userId: user.id)
                            } label: {
                                UserCard(user: user, onFollow: { toggleFollow(for: user.id) })
                                    .padding(.horizontal, 16)
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 76)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private var plantsContent: some View {
        Group {
            let results = filteredPlants
            if results.isEmpty {
                noResultsView
            } else {
                ScrollView {
                    LazyVGrid(columns: plantColumns, spacing: 16) {
                        ForEach(results) { plant in
                            NavigationLink {
                                PlantDetailView(plantName: plant.name)
                            } label: {
                                PlantCard(plant: plant)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private var postsContent: some View {
        Group {
            let results = filteredPosts
            if results.isEmpty {
                noResultsView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(results) { post in
                            NavigationLink {
                                if let specimen = store.visiblePosts.first(where: { $0.id == post.id }) {
                                    PostDetailView(post: specimen.detailItem)
                                } else {
                                    PostDetailView(post: PostItem(cardData: post))
                                }
                            } label: {
                                postResultRow(post)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private var noResultsView: some View {
        EmptyStateView(
            systemImage: "magnifyingglass",
            title: "No results found.",
            description: "Try another keyword."
        )
    }

    private func postResultRow(_ post: PostCardData) -> some View {
        let specimen = store.visiblePosts.first(where: { $0.id == post.id })

        return HStack(alignment: .top, spacing: 12) {
            Group {
                if let assetName = specimen?.imageAssetName ?? post.imageAssetName {
                    Image(assetName)
                        .resizable()
                        .scaledToFill()
                } else if let localImage = specimen?.localImage {
                    Image(uiImage: localImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.phSurface
                        .overlay(
                            Image(systemName: "tree.fill")
                                .foregroundStyle(Color.primaryBlue.opacity(0.35))
                        )
                }
            }
            .frame(width: 92, height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 8) {
                Text(post.content)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(3)

                HStack(spacing: 8) {
                    Avatar(urlString: post.user.avatarUrlString, size: .small)
                    Text(post.user.username)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text("·")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                    Text("\(post.likeCount) likes")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .cardStyle()
    }

    // MARK: - Filtering

    private var filteredUsers: [UserCardData] {
        let authors = Dictionary(
            store.visiblePosts.map { ($0.author.id, $0.author) },
            uniquingKeysWith: { first, _ in first }
        ).values

        let users = authors
            .filter { !moderation.isUserSuppressed($0.id) }
            .map { author in
            if let profile = GardenCommunityProfiles.userCardData(id: author.id) {
                return UserCardData(
                    id: profile.id,
                    username: profile.username,
                    avatarURL: profile.avatarURL,
                    bio: profile.bio,
                    isFollowing: followStore.isFollowing(profile.id)
                )
            }
            return UserCardData(
                id: author.id,
                username: author.username,
                avatarURL: nil,
                bio: "",
                isFollowing: followStore.isFollowing(author.id)
            )
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return users }
        return users.filter { $0.username.localizedCaseInsensitiveContains(trimmed) }
    }

    private var filteredPlants: [PlantCardData] {
        let plants = PlantWikiModel.plants.map { plant in
            let postCount = store.visiblePosts.filter {
                $0.plantName.localizedCaseInsensitiveContains(plant.name)
                    || $0.plantTags.contains { $0.localizedCaseInsensitiveContains(plant.name) }
            }.count

            return PlantCardData(
                id: plant.id,
                name: plant.name,
                coverImageAssetName: plant.imageName.isEmpty ? nil : plant.imageName,
                collectorsCount: 0,
                postsCount: postCount
            )
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return plants }
        return plants.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var filteredPosts: [PostCardData] {
        let posts = store.visiblePosts.map(\.cardData)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return posts }
        return posts.filter { post in
            post.content.localizedCaseInsensitiveContains(trimmed) ||
            post.user.username.localizedCaseInsensitiveContains(trimmed) ||
            post.plantTags.contains { tag in
                tag.name.localizedCaseInsensitiveContains(trimmed)
            }
        }
    }

    private func toggleFollow(for userID: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            followStore.toggleFollow(userID: userID)
        }
    }
}
