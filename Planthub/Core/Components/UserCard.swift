import SwiftUI

// MARK: - View model

struct UserCardData: Identifiable {
    let id: String
    let username: String
    let avatarURL: URL?
    let bio: String
    var isFollowing: Bool
}

// MARK: - UserCard

/// User list row: medium avatar + username + bio (1 line) + trailing FollowButton.
/// When `isCurrentUser` is true the FollowButton is hidden.
struct UserCard: View {

    let user: UserCardData
    var isCurrentUser: Bool = false
    var isFollowLoading: Bool = false
    var onFollow: (() -> Void)? = nil
    var onAvatarTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Avatar(url: user.avatarURL, size: .medium, onTap: onAvatarTap)

            VStack(alignment: .leading, spacing: 3) {
                Text(user.username)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                if !user.bio.isEmpty {
                    Text(user.bio)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if !isCurrentUser {
                FollowButton(
                    isFollowing: user.isFollowing,
                    isLoading: isFollowLoading,
                    action: { onFollow?() }
                )
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        Divider()

        UserCard(
            user: UserCardData(
                id: "1",
                username: "plantlover99",
                avatarURL: nil,
                bio: "Monstera collector · plant dad",
                isFollowing: false
            ),
            onFollow: {}
        )
        .padding(.horizontal, 16)

        Divider()

        UserCard(
            user: UserCardData(
                id: "2",
                username: "fernqueen",
                avatarURL: nil,
                bio: "Ferns & humidity enthusiast",
                isFollowing: true
            ),
            onFollow: {}
        )
        .padding(.horizontal, 16)

        Divider()

        UserCard(
            user: UserCardData(
                id: "3",
                username: "me",
                avatarURL: nil,
                bio: "This is my own account",
                isFollowing: false
            ),
            isCurrentUser: true
        )
        .padding(.horizontal, 16)

        Divider()
    }
}
