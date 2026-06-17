import SwiftUI

// MARK: - View model

struct CommentCardData: Identifiable {
    let id: String
    let userId: String
    let username: String
    let avatarURL: URL?
    let content: String
    let createdAt: Date
    var likeCount: Int
    var isLiked: Bool
}

// MARK: - CommentCard

/// Single comment row: small avatar + username + text + timestamp + like/reply/delete actions.
/// Delete button is only visible when `isCurrentUser` is true.
struct CommentCard: View {

    let comment: CommentCardData
    var isCurrentUser: Bool = false
    var onLike: (() -> Void)? = nil
    var onReply: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onAvatarTap: (() -> Void)? = nil

    @State private var likeScale: CGFloat = 1.0

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Avatar(url: comment.avatarURL, size: .small, onTap: onAvatarTap)

            VStack(alignment: .leading, spacing: 4) {
                // Username + timestamp
                HStack(alignment: .firstTextBaseline) {
                    Text(comment.username)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text(comment.createdAt.phRelative)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }

                // Comment text
                Text(comment.content)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                // Action row
                HStack(spacing: 16) {
                    likeButton
                    if onReply != nil { replyButton }
                    if isCurrentUser { deleteButton }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: Action buttons

    private var likeButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) { likeScale = 1.35 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3)) { likeScale = 1.0 }
            }
            onLike?()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 13))
                    .foregroundStyle(comment.isLiked ? .red : Color.textSecondary)
                    .scaleEffect(likeScale)
                if comment.likeCount > 0 {
                    Text("\(comment.likeCount)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var replyButton: some View {
        Button { onReply?() } label: {
            Text("Reply")
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private var deleteButton: some View {
        Button { onDelete?() } label: {
            Text("Delete")
                .font(.system(size: 12))
                .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
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


