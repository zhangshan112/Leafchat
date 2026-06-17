import SwiftUI

// MARK: - Messages Tab

private enum MessagesTab: String, CaseIterable, Identifiable, Hashable {
    case chats = "Chats"
    case notifications = "Notifications"

    var id: String { rawValue }
}

// MARK: - MessagesView

struct MessagesView: View {

    @Bindable private var chatStore = LocalChatStore.shared
    @ObservedObject private var session = UserSessionStore.shared
    @State private var selectedTab: MessagesTab = .chats
    @State private var notifications: [NotificationCardData] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabBar
                Divider()
                content
            }
            .background(Color.phBackground)
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedTab == .notifications, notifications.contains(where: { !$0.isRead }) {
                        Button("Mark all as read") {
                            markAllAsRead()
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.primaryBlue)
                    }
                }
            }
            .onAppear {
                if let authUser = session.authUser {
                    chatStore.syncCurrentUser(authUser)
                }
            }
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(MessagesTab.allCases) { tab in
                tabButton(tab)
            }
        }
    }

    private func tabButton(_ tab: MessagesTab) -> some View {
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

    private var content: some View {
        TabView(selection: $selectedTab) {
            chatsContent
                .tag(MessagesTab.chats)

            notificationsContent
                .tag(MessagesTab.notifications)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private var notificationsContent: some View {
        Group {
            if notifications.isEmpty {
                EmptyStateView.noNotifications
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(notifications) { notification in
                            NotificationCard(
                                notification: notification,
                                onTap: { markNotificationAsRead(notification.id) }
                            )
                            Divider().padding(.leading, 68)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var chatsContent: some View {
        Group {
            if chatStore.threads.isEmpty {
                EmptyStateView.noChats
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(chatStore.threads) { chat in
                            NavigationLink {
                                ChatView(
                                    chat: ChatItem(
                                        id: chat.id,
                                        userId: chat.id.hasPrefix("chat-") ? String(chat.id.dropFirst(5)) : chat.id,
                                        username: chat.username,
                                        avatarURL: chat.avatarURL,
                                        isMutualFollow: chat.isMutualFollow
                                    )
                                )
                            } label: {
                                ChatRow(chat: chat)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteChat(chat.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }

                            Divider().padding(.leading, 76)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Actions

    private func markAllAsRead() {
        withAnimation(.easeInOut(duration: 0.2)) {
            for index in notifications.indices {
                notifications[index].isRead = true
            }
        }
    }

    private func markNotificationAsRead(_ id: String) {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            notifications[index].isRead = true
        }
    }

    private func deleteChat(_ id: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            chatStore.deleteThread(chatID: id)
        }
    }
}

#Preview {
    MessagesView()
}
