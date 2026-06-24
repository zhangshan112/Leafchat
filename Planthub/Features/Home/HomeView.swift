import SwiftUI

// MARK: - View state

private enum GardenViewState {
    case loading, empty, error, loaded
}

private enum HomeDestination: Hashable {
    case post(id: String)
    case profile(userId: String)
}

// MARK: - HomeView

struct HomeView: View {

    @ObservedObject private var store = GardenFeedStore.shared
    @ObservedObject private var session = UserSessionStore.shared
    @ObservedObject private var tabRouter = AppTabRouter.shared

    @State private var viewState: GardenViewState = .loaded
    @State private var selectedPlot: GardenPlot? = nil
    @State private var navigationPath = NavigationPath()

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var filteredPosts: [SpecimenPost] {
        let visiblePosts = store.visiblePosts
        guard let selectedPlot else { return visiblePosts }
        return visiblePosts.filter { $0.plot == selectedPlot }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                switch viewState {
                case .loading:
                    loadingView
                case .empty:
                    emptyView
                case .error:
                    errorView
                case .loaded:
                    gardenScroll
                }
            }
            .background(gardenBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { navBarItems }
            .navigationDestination(for: String.self) { tagName in
                PlantDetailView(plantName: tagName)
            }
            .navigationDestination(for: HomeDestination.self) { destination in
                switch destination {
                case let .post(id):
                    postDetailDestination(postId: id)
                case let .profile(userId):
                    profileDestination(for: userId)
                }
            }
            .onChange(of: tabRouter.pendingHomePostID) { _, postId in
                guard let postId else { return }
                navigationPath.append(HomeDestination.post(id: postId))
                tabRouter.clearPendingHomePost()
            }
        }
    }

    @ViewBuilder
    private func postDetailDestination(postId: String) -> some View {
        if let post = store.posts.first(where: { $0.id == postId }),
           CommunityModerationStore.shared.isPostVisible(post) {
            PostDetailView(post: post.detailItem)
        } else if store.posts.contains(where: { $0.id == postId }) {
            // Post was hidden (blocked/reported author or reported post) — pop instead of a blank screen.
            NavigationAutoDismissView()
        } else {
            EmptyStateView(
                systemImage: "exclamationmark.triangle",
                title: "Post not found.",
                description: "This post may have been removed.",
                actionTitle: "Go Back",
                action: { popLastDestinationIfNeeded() }
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

    private func popLastDestinationIfNeeded() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }

    // MARK: - Navigation

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

    private var gardenBackground: some View {
        ZStack(alignment: .top) {
            Color.phBackground.ignoresSafeArea()
            LinearGradient(
                colors: [
                    Color(hex: "#7C3AED").opacity(0.09),
                    Color(hex: "#EC4899").opacity(0.03),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.4)
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Main scroll

    private var gardenScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                greetingSection
                gardenPulseSection
                trendingSection
                plotSection
                specimenGridSection
            }
            .padding(.bottom, 24)
        }
        .refreshable { await refreshGarden() }
    }

    // MARK: - 0. Greeting

    private var greetingSection: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(greetingText)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.neonPink)
                        .frame(width: 7, height: 7)
                        .shadow(color: Color.neonPink.opacity(0.6), radius: 3)
                    Text("Community is buzzing today")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.primaryBlue)
                }
            }
            Spacer()
            if let authUser = session.authUser {
                NavigationLink(value: HomeDestination.profile(userId: authUser.id.uuidString)) {
                    ZStack(alignment: .bottomTrailing) {
                        Avatar(urlString: authUser.avatarUrlString, size: .medium)
                        Circle()
                            .fill(Color.neonPink)
                            .frame(width: 11, height: 11)
                            .overlay(Circle().stroke(Color.phBackground, lineWidth: 2))
                            .shadow(color: Color.neonPink.opacity(0.5), radius: 3)
                    }
                    .frame(minWidth: 48, minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning ✨"
        case 12..<18: return "Good afternoon 🌸"
        default:      return "Good evening 🌙"
        }
    }

    // MARK: - 1. Community pulse

    private var gardenPulseSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.savedAmber.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.savedAmber)
                }
                Text("Community Pulse")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.primaryBlue)
                    .textCase(.uppercase)
                    .tracking(0.9)
                Spacer()
                Text("Live")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.likeRed)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Color.likeRed.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(store.pulse.summary)
                .font(.system(size: 15))
                .foregroundStyle(Color.textPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 0) {
                pulseStat(
                    value: store.pulse.newLeavesToday,
                    label: "New posts",
                    icon: "sparkles",
                    color: Color.primaryBlue
                )
                Rectangle()
                    .fill(Color.phBorder)
                    .frame(width: 1, height: 36)
                pulseStat(
                    value: store.pulse.helpRequests,
                    label: "Help calls",
                    icon: "hands.sparkles.fill",
                    color: Color.hotCoral
                )
                Rectangle()
                    .fill(Color.phBorder)
                    .frame(width: 1, height: 36)
                pulseStat(
                    value: store.pulse.activeGardeners,
                    label: "Online",
                    icon: "person.2.fill",
                    color: Color.neonCyan
                )
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primaryBlue.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color(hex: "#7C3AED").opacity(0.08), radius: 14, x: 0, y: 5)
        .padding(.horizontal, 16)
    }

    private func pulseStat(value: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                Text("\(value)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 2. Trending tags

    @ViewBuilder
    private var trendingSection: some View {
        let tags = store.trendingTags
        if !tags.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.hotCoral)
                    Text("Trending")
                        .font(.sectionTitle)
                        .foregroundStyle(Color.textPrimary)
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(tags.enumerated()), id: \.element) { index, tag in
                            NavigationLink(value: tag) {
                                HStack(spacing: 4) {
                                    if index == 0 {
                                        Image(systemName: "flame.fill")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(trendingTagColor(index: index))
                                    }
                                    Text("#\(tag)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(trendingTagColor(index: index))
                                }
                                .padding(.horizontal, 13)
                                .padding(.vertical, 8)
                                .background(trendingTagColor(index: index).opacity(0.10))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(trendingTagColor(index: index).opacity(0.2), lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func trendingTagColor(index: Int) -> Color {
        let palette: [Color] = [
            Color.hotCoral, Color.primaryBlue, Color.neonPink,
            Color.neonCyan, Color.savedAmber, Color.neonOrange
        ]
        return palette[index % palette.count]
    }

    // MARK: - 3. Garden plots

    private var plotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Garden Plots")
                .font(.sectionTitle)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    plotChip(plot: nil, title: "All Plots", icon: "square.grid.2x2", count: store.posts.count)

                    ForEach(GardenPlot.allCases) { plot in
                        plotChip(
                            plot: plot,
                            title: plot.title,
                            icon: plot.icon,
                            count: store.postCount(for: plot)
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func plotChip(plot: GardenPlot?, title: String, icon: String, count: Int) -> some View {
        let isSelected = selectedPlot == plot

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPlot = plot
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? .white : plotAccent(plot))
                    Spacer()
                    Text("\(count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : Color.textSecondary)
                }

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : Color.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(width: 132, height: 96)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? plotAccent(plot) : Color.phSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.clear : plotAccent(plot).opacity(0.25),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func plotAccent(_ plot: GardenPlot?) -> Color {
        guard let plot else { return Color.primaryBlue }
        switch plot {
        case .yellowLeafER:    return Color.savedAmber
        case .succulentCorner: return Color.primaryBlue
        case .newLeafWatch:    return Color.neonCyan
        case .balconyInspo:    return Color.neonPink
        }
    }

    // MARK: - 4. Specimen grid

    private var specimenGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedPlot?.title ?? "Specimen Wall")
                    .font(.sectionTitle)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                if selectedPlot != nil {
                    Button("Show all") {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedPlot = nil }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primaryBlue)
                }
            }
            .padding(.horizontal, 16)

            if filteredPosts.isEmpty {
                Text("No specimens in this plot yet.")
                    .font(.captionText)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                LazyVGrid(columns: gridColumns, alignment: .center, spacing: 16) {
                    ForEach(Array(filteredPosts.enumerated()), id: \.element.id) { index, post in
                        SpecimenCard(
                            post: post,
                            onLike: { store.toggleLike(post.id) },
                            onSave: { store.toggleSaved(post.id) },
                            onComment: {},
                            onCardTap: {
                                navigationPath.append(HomeDestination.post(id: post.id))
                            }
                        )
                        .overlay(alignment: .bottomLeading) {
                            NavigationLink(value: HomeDestination.profile(userId: post.author.id)) {
                                Color.clear
                                    .frame(width: 156, height: 48)
                                    .contentShape(Rectangle())
                            }
                            .padding(.leading, 12)
                            .padding(.bottom, 10)
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                        // Stagger alternate cards for a natural, non-overlapping rhythm
                        .padding(.top, index.isMultiple(of: 2) ? 0 : 10)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading community…")
                .tint(Color.primaryBlue)
                .foregroundStyle(Color.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyView: some View {
        EmptyStateView(
            systemImage: "tree",
            title: "The garden is quiet.",
            description: "Be the first to share a plant specimen today.",
            actionTitle: "Explore Plots",
            action: { withAnimation { viewState = .loaded } }
        )
    }

    private var errorView: some View {
        EmptyStateView(
            systemImage: "cloud.rain",
            title: "Couldn't reach the garden.",
            description: "Pull down to try again.",
            actionTitle: "Retry",
            action: { Task { await refreshGarden() } }
        )
    }

    // MARK: - Actions

    @MainActor
    private func refreshGarden() async {
        viewState = .loading
        try? await Task.sleep(nanoseconds: 600_000_000)
        store.reload()
        viewState = store.posts.isEmpty ? .empty : .loaded
    }
}

// MARK: - Navigation helpers

/// Pops the current navigation destination when moderated content becomes unavailable.
private struct NavigationAutoDismissView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Color.phBackground
            .ignoresSafeArea()
            .onAppear { dismiss() }
    }
}

// MARK: - SpecimenPost → PostItem mapping

extension SpecimenPost {
    /// Adapts a garden specimen into the `PostItem` used by `PostDetailView`,
    /// so tapping a card opens a full post detail with the same content.
    var detailItem: PostItem {
        var tagNames = plantTags
        if !tagNames.contains(where: { $0.localizedCaseInsensitiveCompare(plantName) == .orderedSame }) {
            tagNames.insert(plantName, at: 0)
        }
        let tags = tagNames.enumerated().map { index, name in
            PostPlantTag(id: "\(id)-tag-\(index)", name: name)
        }

        return PostItem(
            id: id,
            user: author,
            imageAssetName: imageAssetName,
            localImage: localImage,
            content: caption,
            createdAt: createdAt,
            likeCount: likeCount,
            commentCount: commentCount,
            isLiked: isLiked,
            isSaved: isSaved,
            plantTags: tags
        )
    }

    var cardData: PostCardData {
        PostCardData(
            id: id,
            user: author,
            imageAssetName: imageAssetName,
            content: caption,
            createdAt: createdAt,
            likeCount: likeCount,
            commentCount: commentCount,
            isLiked: isLiked,
            isSaved: isSaved,
            plantTags: plantTags.enumerated().map { index, name in
                PostPlantTag(id: "\(id)-tag-\(index)", name: name)
            }
        )
    }
}
