import SwiftUI

// MARK: - DiscoverView

struct DiscoverView: View {

    @ObservedObject private var store = GardenFeedStore.shared
    @ObservedObject private var session = UserSessionStore.shared
    @ObservedObject private var tabRouter = AppTabRouter.shared

    @State private var navigationPath = NavigationPath()
    @State private var showPostSheet = false
    @State private var postPendingDeletion: SpecimenPost?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottomTrailing) {
                discoverScroll

                // FAB — create post
                Button {
                    showPostSheet = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#8B5CF6"), Color(hex: "#7C3AED")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .shadow(color: Color.primaryBlue.opacity(0.40), radius: 12, x: 0, y: 6)

                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .background(discoverBackground)
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { navBarItems }
            .navigationDestination(for: String.self) { tagName in
                PlantDetailView(plantName: tagName)
            }
            .navigationDestination(for: DiscoverDestination.self) { destination in
                switch destination {
                case let .post(id):
                    postDetailDestination(postId: id)
                case let .profile(userId):
                    profileDestination(for: userId)
                }
            }
            .onChange(of: tabRouter.pendingHomePostID) { _, postId in
                guard let postId else { return }
                navigationPath.append(DiscoverDestination.post(id: postId))
                tabRouter.clearPendingHomePost()
            }
            .onChange(of: PostDraftStore.shared.pending) { _, draft in
                if draft != nil { showPostSheet = true }
            }
            .onAppear {
                // Handles the case where DiscoverView was off-screen when the draft was set:
                // when the tab switches and the view appears, we check immediately.
                if PostDraftStore.shared.pending != nil {
                    showPostSheet = true
                }
            }
            .sheet(isPresented: $showPostSheet) {
                PostView()
            }
            .alert("Delete this post?", isPresented: deleteConfirmationBinding, presenting: postPendingDeletion) { post in
                Button("Delete", role: .destructive) {
                    store.deletePost(post.id)
                    postPendingDeletion = nil
                }
                Button("Cancel", role: .cancel) {
                    postPendingDeletion = nil
                }
            } message: { _ in
                Text("This removes the post from your Discover feed. This action cannot be undone.")
            }
        }
    }

    // MARK: - Destinations

    private enum DiscoverDestination: Hashable {
        case post(id: String)
        case profile(userId: String)
    }

    @ViewBuilder
    private func postDetailDestination(postId: String) -> some View {
        if let post = store.posts.first(where: { $0.id == postId }),
           CommunityModerationStore.shared.isPostVisible(post) {
            PostDetailView(post: post.detailItem)
        } else {
            EmptyStateView(
                systemImage: "exclamationmark.triangle",
                title: "Post not found.",
                description: "This post may have been removed.",
                actionTitle: "Go Back",
                action: { navigationPath.removeLast() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.phBackground)
        }
    }

    @ViewBuilder
    private func profileDestination(for userId: String) -> some View {
        if let currentUserId = session.authUser?.id.uuidString, userId == currentUserId {
            ProfileView()
        } else {
            UserProfileView(userId: userId)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var navBarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            NavigationLink {
                SearchView(defaultTab: .plants)
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
            }
        }
    }

    // MARK: - Background

    private var discoverBackground: some View {
        ZStack(alignment: .top) {
            Color.phBackground.ignoresSafeArea()
            LinearGradient(
                colors: [
                    Color(hex: "#7C3AED").opacity(0.07),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.3)
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Main Scroll

    private var discoverScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if store.visiblePosts.isEmpty {
                    emptyFeedPlaceholder
                } else {
                    spotlightSection
                    storyFeedSection
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 88)
        }
        .refreshable { await refreshFeed() }
    }

    // MARK: - Daily Pick

    private var spotlightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Daily Pick", subtitle: "One featured plant story selected for today")

            if let post = dailyFeaturedPost {
                DiscoverSpotlightCard(
                    post: post,
                    canDelete: isCurrentUserPost(post),
                    onTap: { navigationPath.append(DiscoverDestination.post(id: post.id)) },
                    onAuthorTap: { navigationPath.append(DiscoverDestination.profile(userId: post.author.id)) },
                    onDelete: { postPendingDeletion = post }
                )
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Story Feed

    private var storyFeedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Plant Stories", subtitle: "Browse updates one story at a time")

            LazyVStack(spacing: 16) {
                ForEach(store.visiblePosts) { post in
                    DiscoverStoryCard(
                        post: post,
                        canDelete: isCurrentUserPost(post),
                        onLike: { store.toggleLike(post.id) },
                        onSave: { store.toggleSaved(post.id) },
                        onComment: { navigationPath.append(DiscoverDestination.post(id: post.id)) },
                        onAuthorTap: { navigationPath.append(DiscoverDestination.profile(userId: post.author.id)) },
                        onCardTap: { navigationPath.append(DiscoverDestination.post(id: post.id)) },
                        onDelete: { postPendingDeletion = post }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var dailyFeaturedPost: SpecimenPost? {
        let posts = store.visiblePosts
        guard !posts.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return posts[day % posts.count]
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { postPendingDeletion != nil },
            set: { if !$0 { postPendingDeletion = nil } }
        )
    }

    private func isCurrentUserPost(_ post: SpecimenPost) -> Bool {
        session.authUser?.id.uuidString == post.author.id
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.sectionTitle)
                    .foregroundStyle(Color.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private var emptyFeedPlaceholder: some View {
        EmptyStateView(
            systemImage: "photo.on.rectangle.angled",
            title: "No posts yet.",
            description: "Be the first to share a plant with the community.",
            actionTitle: "Create Post",
            action: { showPostSheet = true }
        )
        .padding(.vertical, 32)
    }

    // MARK: - Actions

    @MainActor
    private func refreshFeed() async {
        try? await Task.sleep(nanoseconds: 500_000_000)
        store.reload()
    }
}

// MARK: - Discover Spotlight Card

private struct DiscoverSpotlightCard: View {
    let post: SpecimenPost
    let canDelete: Bool
    let onTap: () -> Void
    let onAuthorTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            postImage
                .mediaFill()
                .mediaContainer(aspectRatio: 16.0 / 10.0)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            LinearGradient(
                colors: [.clear, Color.accentBlack.opacity(0.74)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    statusPill
                    Spacer()
                    Text(post.plot.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text(post.plantName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if !post.caption.isEmpty {
                        Text(post.caption)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(2)
                            .lineSpacing(2)
                    }
                }

                Button(action: onAuthorTap) {
                    HStack(spacing: 7) {
                        Avatar(urlString: post.author.avatarUrlString, size: .small)
                        Text(post.author.username)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            if canDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.hotCoral.opacity(0.92), in: Circle())
                        .shadow(color: Color.hotCoral.opacity(0.35), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture(perform: onTap)
        .shadow(color: Color.primaryBlue.opacity(0.18), radius: 18, x: 0, y: 10)
    }

    @ViewBuilder
    private var postImage: some View {
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
                Color.surfaceViolet
                    .overlay(
                        Image(systemName: "photo.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.primaryBlue.opacity(0.35))
                    )
            }
        }
    }

    private var statusPill: some View {
        Label(post.status.label, systemImage: post.status.symbol)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.82), in: Capsule())
    }

    private var statusColor: Color {
        switch post.status {
        case .thriving:   return Color.primaryBlue
        case .recovering: return Color.savedAmber
        case .sprouting:  return Color.hotCoral
        case .resting:    return Color.textSecondary
        }
    }
}

// MARK: - Discover Story Card

private struct DiscoverStoryCard: View {
    let post: SpecimenPost
    let canDelete: Bool
    let onLike: () -> Void
    let onSave: () -> Void
    let onComment: () -> Void
    let onAuthorTap: () -> Void
    let onCardTap: () -> Void
    let onDelete: () -> Void

    @State private var likeScale: CGFloat = 1
    @State private var saveScale: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                ZStack(alignment: .topLeading) {
                    postImage
                        .mediaFill()
                        .mediaContainer(aspectRatio: 4.0 / 3.0)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    statusPill
                        .padding(12)

                    if canDelete {
                        Button(action: onDelete) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Color.hotCoral.opacity(0.92), in: Circle())
                                .shadow(color: Color.hotCoral.opacity(0.30), radius: 8, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        .padding(12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(post.plantName)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Color.textPrimary)
                                .lineLimit(1)

                            if let scientificName = post.scientificName {
                                Text(scientificName)
                                    .font(.system(size: 12).italic())
                                    .foregroundStyle(Color.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)

                        Spacer()

                        Text(post.plot.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.primaryBlue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.tagBackground, in: Capsule())
                            .frame(maxWidth: 126)
                    }

                    if !post.caption.isEmpty {
                        Text(post.caption)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(3)
                            .lineSpacing(3)
                    }

                    if !post.plantTags.isEmpty {
                        tagsRow
                    }
                }
                .padding(.horizontal, 2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .onTapGesture(perform: onCardTap)

            Divider()
                .overlay(Color.phBorder.opacity(0.55))

            HStack(spacing: 0) {
                Button(action: onAuthorTap) {
                    HStack(spacing: 8) {
                        Avatar(urlString: post.author.avatarUrlString, size: .small)
                        Text(post.author.username)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(minHeight: 44)
                    .frame(maxWidth: 150, alignment: .leading)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { likeScale = 1.35 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.3)) { likeScale = 1 }
                    }
                    onLike()
                } label: {
                    Label("\(post.likeCount)", systemImage: post.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 12, weight: post.isLiked ? .semibold : .regular))
                        .foregroundStyle(post.isLiked ? Color.likeRed : Color.textSecondary)
                        .scaleEffect(likeScale)
                }
                .buttonStyle(.plain)

                Button(action: onComment) {
                    Label("\(post.commentCount)", systemImage: "bubble.left")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 14)

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { saveScale = 1.35 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(.spring(response: 0.3)) { saveScale = 1 }
                    }
                    onSave()
                } label: {
                    Image(systemName: post.isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 13))
                        .foregroundStyle(post.isSaved ? Color.savedAmber : Color.textSecondary)
                        .scaleEffect(saveScale)
                }
                .buttonStyle(.plain)
                .padding(.leading, 14)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primaryBlue.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.primaryBlue.opacity(0.08), radius: 14, x: 0, y: 6)
    }

    @ViewBuilder
    private var postImage: some View {
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
                Color.surfaceViolet
                    .overlay(
                        Image(systemName: "photo.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.primaryBlue.opacity(0.35))
                    )
            }
        }
    }

    private var statusPill: some View {
        Label(post.status.label, systemImage: post.status.symbol)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.12), in: Capsule())
    }

    private var tagsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(post.plantTags.prefix(4), id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.primaryBlue)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.tagBackground, in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusColor: Color {
        switch post.status {
        case .thriving:   return Color.primaryBlue
        case .recovering: return Color.savedAmber
        case .sprouting:  return Color.hotCoral
        case .resting:    return Color.textSecondary
        }
    }
}
