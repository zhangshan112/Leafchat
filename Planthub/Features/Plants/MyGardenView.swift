import SwiftUI
import FoundationModels

// MARK: - MyGardenView

struct MyGardenView: View {

    @ObservedObject private var collectionStore = PlantCollectionStore.shared
    @ObservedObject private var sessionStore = UserSessionStore.shared
    @ObservedObject private var historyStore = IdentificationHistoryStore.shared
    @ObservedObject private var tabRouter = AppTabRouter.shared

    @State private var showEncyclopedia = false
    @State private var showAIChat = false
    @State private var selectedAIChatPlant: String? = nil
    @State private var navigationPath = NavigationPath()

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                switch collectionState {
                case .loading:
                    loadingView
                case .empty:
                    emptyView
                case .loaded:
                    gardenScroll
                case .error:
                    errorView
                }
            }
            .background(gardenBackground.ignoresSafeArea())
            .navigationTitle("My Garden")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { navBarItems }
            .navigationDestination(for: String.self) { plantName in
                PlantDetailView(plantName: plantName)
            }
            .sheet(isPresented: $showEncyclopedia) {
                NavigationStack {
                    PlantEncyclopediaView()
                        .navigationTitle("Plant Encyclopedia")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showEncyclopedia = false }
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.primaryBlue)
                            }
                        }
                }
            }
            .sheet(isPresented: $showAIChat) {
                if #available(iOS 26, *) {
                    PlantAIChatView(plantName: selectedAIChatPlant)
                }
            }
            .onAppear {
                if let userId = sessionStore.collectionUserId {
                    collectionStore.load(for: userId)
                }
                presentEncyclopediaIfRequested()
            }
            .onChange(of: tabRouter.shouldOpenPlantEncyclopedia) { _, shouldOpen in
                if shouldOpen {
                    presentEncyclopediaIfRequested()
                }
            }
        }
    }

    // MARK: - Collection State

    private enum GardenContentState {
        case loading, empty, loaded, error
    }

    private var collectionState: GardenContentState {
        switch collectionStore.viewState {
        case .loading: return .loading
        case .empty:   return .empty
        case .loaded:  return .loaded
        case .error:   return .error
        case .idle:    return .empty
        }
    }

    private func presentEncyclopediaIfRequested() {
        guard tabRouter.shouldOpenPlantEncyclopedia else { return }
        showEncyclopedia = true
        tabRouter.clearPlantEncyclopediaRequest()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var navBarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showEncyclopedia = true
            } label: {
                Label("Encyclopedia", systemImage: "book.closed")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primaryBlue)
            }
        }
    }

    // MARK: - Backgrounds

    private var gardenBackground: some View {
        ZStack(alignment: .top) {
            Color.phBackground
            LinearGradient(
                colors: [
                    Color.primaryBlue.opacity(0.07),
                    Color.neonCyan.opacity(0.03),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.35)
            )
        }
    }

    // MARK: - Main Scroll

    private var gardenScroll: some View {
        ScrollView {
            VStack(spacing: 24) {
                gardenStatsSection
                aiCareTodaySection
                collectionGridSection
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Stats

    private var gardenStatsSection: some View {
        HStack(spacing: 0) {
            gardenStat(
                value: "\(collectionStore.count)",
                label: "Plants",
                icon: "tree.fill",
                color: Color.primaryBlue
            )
            Rectangle().fill(Color.phBorder).frame(width: 1, height: 36)
            gardenStat(
                value: "\(historyStore.records.count)",
                label: "Scans",
                icon: "viewfinder",
                color: Color.neonCyan
            )
            Rectangle().fill(Color.phBorder).frame(width: 1, height: 36)
            gardenStat(
                value: "\(recentDaysActive)",
                label: "Days Active",
                icon: "calendar",
                color: Color.savedAmber
            )
        }
        .padding(.vertical, 14)
        .background(Color.phSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.phBorder.opacity(0.5), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func gardenStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var recentDaysActive: Int {
        guard let oldest = historyStore.records.last?.date else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: oldest, to: Date()).day ?? 0
        return max(1, days + 1)
    }

    // MARK: - AI Care Today

    @ViewBuilder
    private var aiCareTodaySection: some View {
        if let tip = todayAICareTip {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "wand.and.sparkles")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.primaryBlue)
                    Text("AI Care Today")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.primaryBlue)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Spacer()
                    Button {
                        selectedAIChatPlant = tip.plantName
                        showAIChat = true
                    } label: {
                        Text("Ask AI")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.primaryBlue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.tagBackground)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Text("**\(tip.plantName):** \(tip.careTip)")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(Color.tagBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.primaryBlue.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
    }

    private struct CareReminder {
        let plantName: String
        let careTip: String
    }

    private var todayAICareTip: CareReminder? {
        // Pick a care tip from the most recent identification record that has one
        guard let record = historyStore.recentRecords.first(where: { !$0.careTip.isEmpty }) else { return nil }
        return CareReminder(plantName: record.commonName, careTip: record.careTip)
    }

    // MARK: - Collection Grid

    private var collectionGridSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("My Plants")
                    .font(.sectionTitle)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Button {
                    showEncyclopedia = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Add Plant")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color.primaryBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.tagBackground)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(collectionStore.items) { item in
                    gardenPlantCard(item)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func gardenPlantCard(_ item: PlantCollectionItem) -> some View {
        Color.clear
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    let cardPadding: CGFloat = 8
                    let labelHeight: CGFloat = 34
                    let imageHeight = max(0, proxy.size.height - (cardPadding * 2) - 8 - labelHeight)

                    VStack(spacing: 8) {
                        ZStack(alignment: .topTrailing) {
                            plantThumbnail(item)
                                .frame(width: max(0, proxy.size.width - (cardPadding * 2)), height: imageHeight)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            Button {
                                selectedAIChatPlant = item.name
                                showAIChat = true
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.primaryBlue)
                                        .frame(width: 26, height: 26)
                                    Image(systemName: "bubble.left.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white)
                                }
                                .shadow(color: Color.primaryBlue.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                            .padding(5)
                        }

                        VStack(spacing: 2) {
                            Text(item.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .multilineTextAlignment(.center)

                            Text(item.scientificName)
                                .font(.system(size: 10))
                                .italic()
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: labelHeight, alignment: .center)
                    }
                    .padding(cardPadding)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                    .background(Color.phSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.phBorder.opacity(0.45), lineWidth: 0.5)
                    )
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onTapGesture {
                navigationPath.append(item.name)
            }
    }

    @ViewBuilder
    private func plantThumbnail(_ item: PlantCollectionItem) -> some View {
        if let assetName = item.imageAssetName {
            Image(assetName)
                .resizable()
                .scaledToFill()
        } else {
            Color.surfaceViolet
                .overlay(
                    Image(systemName: "tree.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.primaryBlue.opacity(0.5))
                )
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading your garden…")
                .tint(Color.primaryBlue)
                .foregroundStyle(Color.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.surfaceViolet)
                        .frame(width: 100, height: 100)
                    Image(systemName: "tree")
                        .font(.system(size: 52))
                        .foregroundStyle(Color.primaryBlue.opacity(0.6))
                }

                VStack(spacing: 8) {
                    Text("Start Your Garden")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    Text("My Garden keeps your plant collection in one place. Add plants from an AI scan result or save them from the Plant Encyclopedia.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }

            VStack(spacing: 12) {
                if #available(iOS 26, *) {
                    Button {
                        AppTabRouter.shared.selectedTab = .identify
                    } label: {
                        Label("Scan a Plant", systemImage: "viewfinder")
                            .primaryButtonStyle()
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: 280)
                }

                Button {
                    showEncyclopedia = true
                } label: {
                    Label("Browse Encyclopedia", systemImage: "book.closed.fill")
                        .secondaryButtonStyle()
                }
                .buttonStyle(.plain)
                .frame(maxWidth: 280)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private var errorView: some View {
        EmptyStateView(
            systemImage: "exclamationmark.triangle",
            title: "Couldn't load your garden.",
            description: "Check your connection and try again.",
            actionTitle: "Retry",
            action: {
                if let userId = sessionStore.collectionUserId {
                    collectionStore.load(for: userId)
                }
            }
        )
    }
}
