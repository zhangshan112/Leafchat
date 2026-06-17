import SwiftUI

// MARK: - View model

struct ChatRowData: Identifiable, Codable, Equatable {
    let id: String
    let username: String
    var avatarURL: URL?
    var lastMessage: String
    var lastMessageAt: Date
    var unreadCount: Int
    var isMutualFollow: Bool
}

// MARK: - ChatRow

/// Chat list row: avatar + username + last message preview + timestamp + unread badge.
struct ChatRow: View {

    let chat: ChatRowData
    var onTap: (() -> Void)? = nil

    var body: some View {
        if let onTap {
            Button(action: onTap) {
                rowContent
            }
            .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    // MARK: Private

    private var rowContent: some View {
        HStack(spacing: 12) {
            Avatar(url: chat.avatarURL, size: .medium)

            VStack(alignment: .leading, spacing: 3) {
                Text(chat.username)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Text(chat.lastMessage)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(chat.lastMessageAt.phRelative)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)

                if chat.unreadCount > 0 {
                    unreadBadge
                } else {
                    // Keep vertical space consistent
                    Spacer().frame(height: 20)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var unreadBadge: some View {
        Text(chat.unreadCount > 99 ? "99+" : "\(chat.unreadCount)")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(minWidth: 20, minHeight: 20)
            .background(Color.primaryBlue)
            .clipShape(Capsule())
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

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        Divider()
        ChatRow(chat: ChatRowData(
            id: "1",
            username: "fernqueen",
            avatarURL: nil,
            lastMessage: "That's a gorgeous new leaf!",
            lastMessageAt: Date().addingTimeInterval(-300),
            unreadCount: 3,
            isMutualFollow: true
        ))
        Divider()
        ChatRow(chat: ChatRowData(
            id: "2",
            username: "plantlover99",
            avatarURL: nil,
            lastMessage: "Did you repot your monstera yet?",
            lastMessageAt: Date().addingTimeInterval(-7200),
            unreadCount: 0,
            isMutualFollow: true
        ))
        Divider()
        ChatRow(chat: ChatRowData(
            id: "3",
            username: "cactus_crew",
            avatarURL: nil,
            lastMessage: "Check out this rare Gymnocalycium!",
            lastMessageAt: Date().addingTimeInterval(-86400),
            unreadCount: 120,
            isMutualFollow: true
        ))
        Divider()
    }
}
