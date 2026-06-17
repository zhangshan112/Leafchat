import SwiftUI

// MARK: - View models

struct PostCardUser {
    let id: String
    let username: String
    let avatarUrlString: String?
}

struct PostPlantTag: Identifiable {
    let id: String
    let name: String
}

struct PostCardData: Identifiable {
    let id: String
    let user: PostCardUser
    let imageAssetName: String?
    let content: String
    let createdAt: Date
    var likeCount: Int
    var commentCount: Int
    var isLiked: Bool
    var isSaved: Bool
    let plantTags: [PostPlantTag]
}

// MARK: - PostCard

/// Feed card showing avatar, image carousel, action bar, body text, and plant tags.
struct PostCard: View {

    let post: PostCardData
    var onLike: (() -> Void)? = nil
    var onComment: (() -> Void)? = nil
    var onSave: (() -> Void)? = nil
    var onAvatarTap: (() -> Void)? = nil
    var onTagTap: ((PostPlantTag) -> Void)? = nil

    @State private var likeScale: CGFloat = 1.0
    @State private var saveScale: CGFloat = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 10)

            if let assetName = post.imageAssetName {
                PostImageCarousel(assetNames: [assetName])
            }

            VStack(alignment: .leading, spacing: 8) {
                actionBar
                if !post.content.isEmpty {
                    contentText
                }
                if !post.plantTags.isEmpty {
                    tagsRow
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: Subviews

    private var header: some View {
        HStack(spacing: 10) {
            Avatar(urlString: post.user.avatarUrlString, size: .medium, onTap: onAvatarTap)
            VStack(alignment: .leading, spacing: 2) {
                Text(post.user.username)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(post.createdAt.phRelative)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
        }
    }

    private var actionBar: some View {
        HStack(spacing: 20) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { likeScale = 1.45 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3)) { likeScale = 1.0 }
                }
                onLike?()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: post.isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(post.isLiked ? Color.likeRed : Color.textSecondary)
                        .scaleEffect(likeScale)
                    Text("\(post.likeCount)")
                        .font(.system(size: 14, weight: post.isLiked ? .semibold : .regular))
                        .foregroundStyle(post.isLiked ? Color.likeRed : Color.textSecondary)
                }
            }
            .buttonStyle(.plain)

            Button { onComment?() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "bubble.left")
                        .foregroundStyle(Color.textSecondary)
                    Text("\(post.commentCount)")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { saveScale = 1.45 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(.spring(response: 0.3)) { saveScale = 1.0 }
                }
                onSave?()
            } label: {
                Image(systemName: post.isSaved ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(post.isSaved ? Color.savedAmber : Color.textSecondary)
                    .scaleEffect(saveScale)
            }
            .buttonStyle(.plain)
        }
    }

    private var contentText: some View {
        Text(post.content)
            .font(.system(size: 15))
            .foregroundStyle(Color.textPrimary)
            .lineLimit(2)
    }

    private var tagsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(post.plantTags) { tag in
                    Tag(name: tag.name, onTap: { onTagTap?(tag) })
                }
            }
        }
    }
}

// MARK: - Date helper

private extension Date {
    var phRelative: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
