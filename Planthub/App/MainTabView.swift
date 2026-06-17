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
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTabRouter.Tab.home)

            PlantsView()
                .tabItem { Label("Plants", systemImage: "leaf.fill") }
                .tag(AppTabRouter.Tab.plants)

            PostView()
                .tabItem { Label("Post", systemImage: "plus.circle.fill") }
                .tag(AppTabRouter.Tab.post)

            MessagesView()
                .tabItem { Label("Messages", systemImage: "message.fill") }
                .tag(AppTabRouter.Tab.messages)

            ProfileView(onLogout: onLogout, onAccountDeleted: onAccountDeleted)
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(AppTabRouter.Tab.profile)
        }
        .tint(Color.primaryBlue)
        .onChange(of: PostDraftStore.shared.pending) { _, draft in
            if draft != nil { tabRouter.selectedTab = .post }
        }
        .paywallSheet()
    }
}

#Preview {
    MainTabView()
}
