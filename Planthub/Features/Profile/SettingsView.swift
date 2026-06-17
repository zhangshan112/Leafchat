import SwiftUI
import UserNotifications

// MARK: - SettingsView

struct SettingsView: View {
    @Environment(\.authAPIService) private var authAPIService

    var onLogout: () -> Void = {}
    var onAccountDeleted: () -> Void = {}

    @State private var preferences = PushNotificationPreferencesStore.shared.preferences
    @State private var pushAuthorizationStatus: UNAuthorizationStatus = .notDetermined

    @State private var publicCollection = true
    @State private var publicPosts = true
    @State private var allowMessages = true

    @State private var showLogoutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountErrorMessage: String?

    var body: some View {
        List {
            Section("Notifications") {
                if pushAuthorizationStatus == .denied {
                    Button {
                        PushNotificationService.shared.openSystemNotificationSettings()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notifications are disabled")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)

                            Text("Open Settings to enable alerts for likes, comments, and messages.")
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                }

                Toggle("Likes", isOn: notificationBinding(\.likes))
                Toggle("Comments", isOn: notificationBinding(\.comments))
                Toggle("Follows", isOn: notificationBinding(\.follows))
                Toggle("Messages", isOn: notificationBinding(\.messages))
            }

            Section("Privacy") {
                Toggle("Public Collection", isOn: $publicCollection)
                Toggle("Public Posts", isOn: $publicPosts)
                Toggle("Allow Messages", isOn: $allowMessages)
            }

            Section("Account") {
                NavigationLink {
                    BlockedUsersView()
                } label: {
                    Text("Blocked Users")
                }
            }

            Section("About") {
                NavigationLink("Terms of Service") {
                    LegalPlaceholderView(title: "Terms of Service", url: LegalLinks.termsOfService)
                }

                NavigationLink("Privacy Policy") {
                    LegalPlaceholderView(title: "Privacy Policy", url: LegalLinks.privacyPolicy)
                }

                NavigationLink("Technical Support") {
                    LegalPlaceholderView(title: "Technical Support", url: LegalLinks.technicalSupport)
                }
            }

            Section {
                SettingsActionRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: "Log Out",
                    subtitle: "Sign out of your account",
                    tint: Color.primaryBlue,
                    action: { showLogoutConfirmation = true }
                )

                SettingsActionRow(
                    icon: "person.crop.circle.badge.minus",
                    title: "Delete Account",
                    subtitle: "Permanently remove your account and data",
                    tint: .red,
                    isLoading: isDeletingAccount,
                    action: { showDeleteAccountConfirmation = true }
                )
                .disabled(isDeletingAccount)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.phBackground)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await PushNotificationService.shared.refreshAuthorizationStatus()
            pushAuthorizationStatus = PushNotificationService.shared.authorizationStatus
            preferences = PushNotificationPreferencesStore.shared.preferences
        }
        .confirmationDialog(
            "Log Out?",
            isPresented: $showLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Log Out", role: .destructive) {
                onLogout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can sign back in anytime with your account.")
        }
        .alert("Delete Account?", isPresented: $showDeleteAccountConfirmation) {
            Button("Delete Account", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account, posts, and plant collection. This action cannot be undone.")
        }
        .alert(
            "Unable to Delete Account",
            isPresented: Binding(
                get: { deleteAccountErrorMessage != nil },
                set: { if !$0 { deleteAccountErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteAccountErrorMessage ?? "")
        }
    }

    private func notificationBinding(
        _ keyPath: WritableKeyPath<PushNotificationPreferences, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { preferences[keyPath: keyPath] },
            set: { newValue in
                preferences[keyPath: keyPath] = newValue
                PushNotificationService.shared.updatePreferences(preferences)
            }
        )
    }

    private func deleteAccount() {
        guard !isDeletingAccount else { return }

        isDeletingAccount = true
        Task {
            do {
                try await authAPIService.deleteAccount()
                onAccountDeleted()
            } catch {
                deleteAccountErrorMessage = error.localizedDescription
            }
            isDeletingAccount = false
        }
    }
}

// MARK: - Settings Action Row

private struct SettingsActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(tint)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
