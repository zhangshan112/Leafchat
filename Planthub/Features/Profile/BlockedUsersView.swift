import SwiftUI

// MARK: - BlockedUsersView

struct BlockedUsersView: View {
    @ObservedObject private var moderation = CommunityModerationStore.shared

    var body: some View {
        Group {
            if moderation.blockedUsers.isEmpty {
                EmptyStateView(
                    systemImage: "person.crop.circle.badge.checkmark",
                    title: "No blocked users.",
                    description: "Users you block will appear here."
                )
            } else {
                List {
                    ForEach(moderation.blockedUsers) { user in
                        HStack(spacing: 12) {
                            UserCard(
                                user: UserCardData(
                                    id: user.id,
                                    username: user.username,
                                    avatarURL: nil,
                                    bio: "Blocked on \(user.blockedAt.formatted(date: .abbreviated, time: .omitted))",
                                    isFollowing: false
                                ),
                                isCurrentUser: true
                            )

                            Button("Unblock") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    moderation.unblockUser(id: user.id)
                                }
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.primaryBlue)
                        }
                        .listRowBackground(Color.phBackground)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.phBackground)
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
    }
}
