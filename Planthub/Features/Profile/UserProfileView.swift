import SwiftUI

// MARK: - UserProfile Tab

private enum UserProfileTab: String, CaseIterable, Identifiable {
    case posts = "Posts"
    case collection = "Collection"

    var id: String { rawValue }
}

// MARK: - UserProfileView

struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss

    let userId: String

    @ObservedObject private var store = GardenFeedStore.shared
    @ObservedObject private var moderation = CommunityModerationStore.shared
    @ObservedObject private var session = UserSessionStore.shared
    @ObservedObject private var followStore = FollowStore.shared

    @State private var selectedTab: UserProfileTab = .posts
    @State private var isShowingReportSheet = false
    @State private var isShowingBlockConfirmation = false

    private let threeColumnGrid = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    private var authorPosts: [SpecimenPost] {
        store.visiblePosts.filter { $0.author.id == userId }
    }

    private var profileAuthor: PostCardUser {
        authorPosts.first?.author
            ?? store.posts.first(where: { $0.author.id == userId })?.author
            ?? GardenCommunityProfiles.postCardUser(id: userId)
    }

    private var headerData: ProfileHeaderData {
        GardenCommunityProfiles.profileHeader(
            userId: userId,
            postsCount: authorPosts.count,
            isFollowing: followStore.isFollowing(userId)
        )
    }

    private var isMutualFollow: Bool {
        followStore.isFollowing(userId)
    }

    var body: some View {
        Group {
            if moderation.isUserSuppressed(userId) {
                EmptyStateView(
                    systemImage: "eye.slash",
                    title: "This user is hidden.",
                    description: moderation.isUserBlocked(userId)
                        ? "You blocked this gardener. Unblock them in Settings if you change your mind."
                        : "You reported this gardener. Their posts are hidden from your feed."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                profileContent
            }
        }
        .background(Color.phBackground)
        .navigationTitle(profileAuthor.username)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !moderation.isUserSuppressed(userId) {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            isShowingBlockConfirmation = true
                        } label: {
                            Label("Block User", systemImage: "person.slash")
                        }

                        Button {
                            isShowingReportSheet = true
                        } label: {
                            Label("Report User", systemImage: "flag")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(Color.textPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingReportSheet) {
            ReportContentSheet(
                title: "Report User",
                message: "Tell us what went wrong. Reported users are hidden from your feed immediately."
            ) { submission in
                moderation.reportUser(
                    id: userId,
                    username: profileAuthor.username,
                    submission: submission
                )
                dismiss()
            }
        }
        .confirmationDialog(
            "Block \(profileAuthor.username)?",
            isPresented: $isShowingBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button("Block User", role: .destructive) {
                moderation.blockUser(id: userId, username: profileAuthor.username)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will no longer see their posts or messages. You can unblock them later in Settings.")
        }
        .onAppear {
            if let authUser = session.authUser {
                followStore.syncCurrentUser(authUser)
            }
        }
    }

    // MARK: - Profile content

    private var profileContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileHeader(
                    user: headerData,
                    isCurrentUser: false,
                    onFollow: toggleFollow
                )

                actionRow
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                tabBar

                content
                    .padding(.top, 12)
            }
        }
    }

    // MARK: - Header / Actions

    private var actionRow: some View {
        HStack(spacing: 12) {
            FollowButton(isFollowing: followStore.isFollowing(userId)) {
                toggleFollow()
            }

            NavigationLink {
                ChatView(
                    chat: ChatItem(
                        id: "chat-\(profileAuthor.id)",
                        userId: profileAuthor.id,
                        username: profileAuthor.username,
                        avatarURL: profileAuthor.avatarUrlString.flatMap(URL.init(string:)),
                        isMutualFollow: isMutualFollow
                    )
                )
            } label: {
                Text("Message")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isMutualFollow ? Color.primaryBlue : Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isMutualFollow ? Color.primaryBlue : Color.phBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isMutualFollow)
            .opacity(isMutualFollow ? 1 : 0.55)
        }
    }

    private func toggleFollow() {
        withAnimation(.easeInOut(duration: 0.2)) {
            followStore.toggleFollow(userID: userId)
        }
    }

    // MARK: - Tabs

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(UserProfileTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 16)
    }

    private func tabButton(_ tab: UserProfileTab) -> some View {
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
        case .posts:
            postsContent

        case .collection:
            EmptyStateView.noPlants
                .frame(minHeight: 320)
        }
    }

    private var postsContent: some View {
        Group {
            if authorPosts.isEmpty {
                EmptyStateView(
                    systemImage: "photo.on.rectangle",
                    title: "No posts yet.",
                    description: "This gardener hasn't shared anything yet."
                )
                .frame(minHeight: 320)
            } else {
                LazyVGrid(columns: threeColumnGrid, spacing: 2) {
                    ForEach(authorPosts) { post in
                        NavigationLink {
                            PostDetailView(post: post.detailItem)
                        } label: {
                            postThumbnail(post)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 24)
            }
        }
    }

    private func postThumbnail(_ post: SpecimenPost) -> some View {
        Group {
            if let assetName = post.imageAssetName {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            } else if let localImage = post.localImage {
                Image(uiImage: localImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.phSurface
                    .overlay(
                        Image(systemName: "leaf.fill")
                            .foregroundStyle(Color.primaryBlue.opacity(0.35))
                    )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
    }
}
