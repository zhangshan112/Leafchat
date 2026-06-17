import SwiftUI

// MARK: - View model

struct NotificationCardData: Identifiable {
    let id: String
    let actorUsername: String
    let actorAvatarURL: URL?
    let message: String
    let createdAt: Date
    var isRead: Bool
}

// MARK: - NotificationCard

/// Notification list row.
/// Unread state: left primaryBlue dot + primaryBlue @ 5% opacity background.
/// Read state: no dot, transparent background.
struct NotificationCard: View {

    let notification: NotificationCardData
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button { onTap?() } label: {
            HStack(spacing: 12) {
                unreadDot

                Avatar(url: notification.actorAvatarURL, size: .small)

                VStack(alignment: .leading, spacing: 3) {
                    Text(notification.message)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(notification.createdAt.phRelative)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                notification.isRead
                    ? Color.clear
                    : Color.primaryBlue.opacity(0.05)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: notification.isRead)
    }

    // MARK: Private

    private var unreadDot: some View {
        Circle()
            .fill(notification.isRead ? Color.clear : Color.primaryBlue)
            .frame(width: 8, height: 8)
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
        NotificationCard(notification: NotificationCardData(
            id: "1",
            actorUsername: "fernqueen",
            actorAvatarURL: nil,
            message: "fernqueen liked your post.",
            createdAt: Date().addingTimeInterval(-120),
            isRead: false
        ))
        Divider()
        NotificationCard(notification: NotificationCardData(
            id: "2",
            actorUsername: "plantlover99",
            actorAvatarURL: nil,
            message: "plantlover99 started following you.",
            createdAt: Date().addingTimeInterval(-3600),
            isRead: true
        ))
        Divider()
        NotificationCard(notification: NotificationCardData(
            id: "3",
            actorUsername: "monstera_dad",
            actorAvatarURL: nil,
            message: "monstera_dad commented: \"Beautiful leaf!\"",
            createdAt: Date().addingTimeInterval(-86400),
            isRead: false
        ))
        Divider()
    }
}
