import SwiftUI

// MARK: - Profile Tab

private enum ProfileTab: String, CaseIterable, Identifiable {
    case posts = "Posts"
    case collection = "Collection"
    case saved = "Saved"

    var id: String { rawValue }
}

// MARK: - ProfileView

struct ProfileView: View {
    var onLogout: () -> Void = {}
    var onAccountDeleted: () -> Void = {}

    @ObservedObject private var store = GardenFeedStore.shared
    @ObservedObject private var session = UserSessionStore.shared
    @ObservedObject private var collectionStore = PlantCollectionStore.shared
    @ObservedObject private var tabRouter = AppTabRouter.shared
    @Bindable private var entitlements = EntitlementStore.shared

    @State private var selectedTab: ProfileTab = .posts
    @State private var isShowingEditProfile = false

    private let collectionGrid = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private let postCardGrid = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var collectionUserId: String? {
        session.collectionUserId
    }

    private var myPosts: [SpecimenPost] {
        guard let userId = session.authUser?.id.uuidString else { return [] }
        return store.posts.filter { $0.author.id == userId }
    }

    private var savedPosts: [SpecimenPost] {
        store.savedVisiblePosts
    }

    private var headerData: ProfileHeaderData? {
        guard let profile = session.authUser?.profileHeaderData else { return nil }

        return ProfileHeaderData(
            id: profile.id,
            username: profile.username,
            avatarUrlString: profile.avatarUrlString,
            bio: profile.bio,
            country: profile.country,
            postsCount: myPosts.count,
            plantsCount: collectionStore.count,
            followersCount: profile.followersCount,
            followingCount: profile.followingCount,
            isFollowing: false,
            subscriptionTier: entitlements.subscriptionTier
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if let headerData {
                    profileContent(headerData: headerData)
                } else {
                    ProgressView()
                        .tint(Color.primaryBlue)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color.phBackground)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView(onLogout: onLogout, onAccountDeleted: onAccountDeleted)
                    } label: {
                        Image(systemName: "gear")
                            .foregroundStyle(Color.textPrimary)
                    }
                }
            }
            .navigationDestination(isPresented: $isShowingEditProfile) {
                if let initialProfile = session.authUser?.profileHeaderData {
                    EditProfileView(initialProfile: initialProfile)
                }
            }
            .task {
                loadCollectionIfNeeded()
            }
            .onChange(of: selectedTab) { _, tab in
                if tab == .collection {
                    loadCollectionIfNeeded()
                }
            }
            .onChange(of: session.collectionUserId) { _, _ in
                loadCollectionIfNeeded()
            }
        }
    }

    private func profileContent(headerData: ProfileHeaderData) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileHeader(
                    user: headerData,
                    isCurrentUser: true,
                    onEditProfile: { isShowingEditProfile = true }
                )
                .id(session.authUser?.updatedAt)

                subscriptionEntryBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                tabBar

                content
                    .padding(.top, 12)
            }
        }
    }

    private func loadCollectionIfNeeded() {
        guard let collectionUserId else { return }
        collectionStore.load(for: collectionUserId)
    }

    // MARK: - Tabs

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ProfileTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 16)
    }

    private var subscriptionEntryBar: some View {
        NavigationLink {
            ProfileStoreView()
                .navigationTitle("Subscription")
                .navigationBarTitleDisplayMode(.inline)
        } label: {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.primaryBlue)
                    Text("Subscription")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                }

                Spacer()

                Text(entitlements.subscriptionTier.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.primaryBlue)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Color.phSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primaryBlue.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func tabButton(_ tab: ProfileTab) -> some View {
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
            postsGrid

        case .collection:
            collectionContent

        case .saved:
            savedGrid
        }
    }

    private var postsGrid: some View {
        Group {
            if myPosts.isEmpty {
                EmptyStateView(
                    systemImage: "photo.on.rectangle",
                    title: "No posts yet.",
                    description: "Share your first plant moment."
                )
                .frame(minHeight: 320)
            } else {
                LazyVGrid(columns: postCardGrid, spacing: 14) {
                    ForEach(myPosts) { post in
                        NavigationLink {
                            PostDetailView(post: post.detailItem)
                        } label: {
                            profilePostCard(post)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    private var savedGrid: some View {
        Group {
            if savedPosts.isEmpty {
                EmptyStateView(
                    systemImage: "photo.on.rectangle",
                    title: "No saved posts yet.",
                    description: "Save posts to find them here."
                )
                .frame(minHeight: 320)
            } else {
                LazyVGrid(columns: postCardGrid, spacing: 14) {
                    ForEach(savedPosts) { post in
                        NavigationLink {
                            PostDetailView(post: post.detailItem)
                        } label: {
                            profilePostCard(post)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    private var collectionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Plants")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Text("\(collectionStore.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.primaryBlue)
            }
            .padding(.horizontal, 16)

            switch collectionStore.viewState {
            case .idle, .loading:
                ProgressView()
                    .tint(Color.primaryBlue)
                    .frame(maxWidth: .infinity, minHeight: 320)

            case .empty:
                EmptyStateView(
                    systemImage: "tree.fill",
                    title: "No plants yet.",
                    description: "Browse the encyclopedia and add plants you grow to your collection.",
                    actionTitle: "Browse Encyclopedia",
                    action: { tabRouter.openPlants() }
                )
                .frame(minHeight: 320)

            case let .error(message):
                VStack(spacing: 12) {
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.hotCoral)
                        .multilineTextAlignment(.center)

                    PrimaryButton(title: "Try Again") {
                        loadCollectionIfNeeded()
                    }
                    .frame(maxWidth: 200)
                }
                .frame(maxWidth: .infinity, minHeight: 320)
                .padding(.horizontal, 16)

            case .loaded:
                LazyVGrid(columns: collectionGrid, spacing: 16) {
                    ForEach(collectionStore.items) { item in
                        NavigationLink {
                            collectionDetailView(for: item)
                        } label: {
                            PlantCollectionCard(plant: item.cardData)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private func collectionDetailView(for item: PlantCollectionItem) -> some View {
        if let wikiPlant = PlantWikiModel.plant(id: item.wikiPlantId) {
            PlantDetailView(plant: wikiPlant)
        } else {
            PlantDetailView(plantName: item.name)
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
                        Image(systemName: "tree.fill")
                            .foregroundStyle(Color.primaryBlue.opacity(0.35))
                    )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
    }

    private func profilePostCard(_ post: SpecimenPost) -> some View {
        ZStack(alignment: .bottomLeading) {
            postThumbnail(post)
                .mediaFill()
                .mediaContainer(aspectRatio: 4.0 / 5.0)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            LinearGradient(
                colors: [.clear, Color.accentBlack.opacity(0.78)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(post.plantName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Avatar(urlString: post.author.avatarUrlString, size: .small)
                        .frame(width: 20, height: 20)
                    Text(post.author.username)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.84))
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Label("\(post.likeCount)", systemImage: "heart.fill")
                    Label("\(post.commentCount)", systemImage: "bubble.left.fill")
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.76))
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primaryBlue.opacity(0.12), lineWidth: 1)
        )
    }
}
