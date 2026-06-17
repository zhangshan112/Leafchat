import SwiftUI

// MARK: - View model

struct ProfileHeaderData {
    let id: String
    let username: String
    let avatarUrlString: String?
    let bio: String
    let country: String
    let postsCount: Int
    let plantsCount: Int
    let followersCount: Int
    let followingCount: Int
    var isFollowing: Bool
    var subscriptionTier: SubscriptionTier = .none
}

// MARK: - ProfileHeader

/// Profile page header.
/// Own profile: shows "Edit Profile" button top-right.
/// Other user: shows FollowButton top-right.
struct ProfileHeader: View {

    let user: ProfileHeaderData
    var isCurrentUser: Bool = false
    var isFollowLoading: Bool = false
    var onEditProfile: (() -> Void)? = nil
    var onFollow: (() -> Void)? = nil
    var onAvatarTap: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            topRow
            userInfo
            statsRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }

    // MARK: Subviews

    private var topRow: some View {
        HStack(alignment: .top) {
            Avatar(urlString: user.avatarUrlString, size: .large, onTap: onAvatarTap)
            Spacer()
            actionButton
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isCurrentUser {
            Button { onEditProfile?() } label: {
                Text("Edit Profile")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.primaryBlue)
                    .padding(.horizontal, 16)
                    .frame(height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primaryBlue, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        } else {
            FollowButton(
                isFollowing: user.isFollowing,
                isLoading: isFollowLoading,
                action: { onFollow?() }
            )
        }
    }

    private var userInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(user.username)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                if user.subscriptionTier == .advanced {
                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Plus")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Color.primaryBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.tagBackground)
                    .clipShape(Capsule())
                } else if user.subscriptionTier == .basic {
                    HStack(spacing: 4) {
                        Image(systemName: "leaf")
                            .font(.system(size: 10, weight: .bold))
                        Text("Basic")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Color.neonCyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.surfaceCyan)
                    .clipShape(Capsule())
                }
            }

            if !user.bio.isEmpty {
                Text(user.bio)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !user.country.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                    Text(user.country)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statColumn(value: user.postsCount, label: "Posts", accentColor: Color.primaryBlue)
            Rectangle().fill(Color.phBorder).frame(width: 1, height: 36)
            statColumn(value: user.plantsCount, label: "Plants", accentColor: Color.neonCyan)
            Rectangle().fill(Color.phBorder).frame(width: 1, height: 36)
            statColumn(value: user.followersCount, label: "Followers", accentColor: Color.neonPink)
            Rectangle().fill(Color.phBorder).frame(width: 1, height: 36)
            statColumn(value: user.followingCount, label: "Following", accentColor: Color.savedAmber)
        }
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primaryBlue.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color(hex: "#7C3AED").opacity(0.06), radius: 10, x: 0, y: 3)
    }

    private func statColumn(value: Int, label: String, accentColor: Color) -> some View {
        VStack(spacing: 3) {
            Text(formatCount(value))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(accentColor)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatCount(_ count: Int) -> String {
        switch count {
        case 0 ..< 1_000:       return "\(count)"
        case 1_000 ..< 1_000_000: return String(format: "%.1fk", Double(count) / 1_000)
        default:                 return String(format: "%.1fm", Double(count) / 1_000_000)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        // Own profile
        ProfileHeader(
            user: ProfileHeaderData(
                id: "1",
                username: "plantlover99",
                avatarUrlString: nil,
                bio: "Monstera collector · plant dad · Amsterdam",
                country: "Netherlands",
                postsCount: 42,
                plantsCount: 18,
                followersCount: 1230,
                followingCount: 87,
                isFollowing: false
            ),
            isCurrentUser: true,
            onEditProfile: {}
        )

        Divider().padding(.horizontal, 16)

        // Other user profile
        ProfileHeader(
            user: ProfileHeaderData(
                id: "2",
                username: "fernqueen",
                avatarUrlString: nil,
                bio: "Ferns & humidity enthusiast",
                country: "United Kingdom",
                postsCount: 108,
                plantsCount: 34,
                followersCount: 4500,
                followingCount: 213,
                isFollowing: false
            ),
            isCurrentUser: false,
            onFollow: {}
        )
    }
}
