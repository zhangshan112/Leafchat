import SwiftUI

struct MainTabView: View {
    var onLogout: () -> Void = {}
    var onAccountDeleted: () -> Void = {}

    init(onLogout: @escaping () -> Void = {}, onAccountDeleted: @escaping () -> Void = {}) {
        self.onLogout = onLogout
        self.onAccountDeleted = onAccountDeleted

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.shadowColor = UIColor(Color(hex: "#7C3AED").opacity(0.08))

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    @ObservedObject private var tabRouter = AppTabRouter.shared

    var body: some View {
        TabView(selection: $tabRouter.selectedTab) {

            identifyTab
                .tabItem { Label("Identify", systemImage: "camera.viewfinder") }
                .tag(AppTabRouter.Tab.identify)

            MyGardenView()
                .tabItem { Label("My Garden", systemImage: "tree.fill") }
                .tag(AppTabRouter.Tab.myGarden)

            DiscoverView()
                .tabItem { Label("Discover", systemImage: "safari.fill") }
                .tag(AppTabRouter.Tab.discover)

            MessagesView()
                .tabItem { Label("Chat", systemImage: "message.fill") }
                .tag(AppTabRouter.Tab.messages)

            ProfileView(onLogout: onLogout, onAccountDeleted: onAccountDeleted)
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(AppTabRouter.Tab.profile)
        }
        .tint(Color.primaryBlue)
        .onChange(of: PostDraftStore.shared.pending) { _, draft in
            // Post drafts (from AI identification results) open the sheet in DiscoverView
            if draft != nil { tabRouter.selectedTab = .discover }
        }
        .paywallSheet()
    }

    // MARK: - Identify Tab (iOS 26+ required)

    @ViewBuilder
    private var identifyTab: some View {
        if #available(iOS 26, *) {
            IdentifyView()
        } else {
            identifyFallbackView
        }
    }

    private var identifyFallbackView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 16) {
                        Image(systemName: "wand.and.sparkles")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.primaryBlue.opacity(0.5))
                        VStack(spacing: 8) {
                            Text("AI Features require iOS 26")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Color.textPrimary)
                            Text("Update your device to iOS 26 or later to access AI plant identification, health diagnosis, and smart care reminders.")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                    }
                    .padding(.top, 40)

                    // Alternative paths while on older iOS
                    VStack(spacing: 12) {
                        Text("In the meantime, explore:")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            AppTabRouter.shared.openPlants()
                        } label: {
                            fallbackActionRow(
                                icon: "tree.fill",
                                title: "Browse My Garden",
                                subtitle: "Manage your plant collection",
                                color: Color.primaryBlue
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            AppTabRouter.shared.selectedTab = .discover
                        } label: {
                            fallbackActionRow(
                                icon: "person.2.fill",
                                title: "Explore Community",
                                subtitle: "Discover what others are growing",
                                color: Color.neonCyan
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 40)
            }
            .background(Color.phBackground.ignoresSafeArea())
            .navigationTitle("Identify")
        }
    }

    private func fallbackActionRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(14)
        .background(Color.phSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.phBorder.opacity(0.6), lineWidth: 0.5)
        )
    }
}
