import SwiftUI
import UIKit

/// Post-registration profile setup — avatar, bio, and location with optional skip.
struct CompleteProfileView: View {

    var onComplete: () -> Void = {}

    @Environment(\.authAPIService) private var authAPIService
    @ObservedObject private var sessionStore = UserSessionStore.shared

    @State private var bio = ""
    @State private var location = ""
    @State private var selectedAvatarImage: UIImage?
    @State private var avatarDidChange = false
    @State private var isShowingAvatarSourceSheet = false
    @State private var pendingAvatarSource: ProfileAvatarSource?
    @State private var activeAvatarSource: ProfileAvatarSource?
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                    .padding(.top, 40)
                    .padding(.bottom, 32)

                VStack(spacing: 20) {
                    avatarSection
                    formSection

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.hotCoral)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    PrimaryButton(title: "Continue") {
                        Task { await handleContinue() }
                    }
                    .disabled(isSaving)

                    Button("Skip for now") {
                        onComplete()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.primaryBlue)
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .authScreenStyle()
        .authLoadingOverlay(isPresented: isSaving, message: "Saving your profile...")
        .sheet(isPresented: $isShowingAvatarSourceSheet, onDismiss: presentPendingAvatarSource) {
            CompleteProfileAvatarSourceSheet(
                sources: ProfileAvatarSource.availableSources,
                canRemovePhoto: selectedAvatarImage != nil || currentAvatarURL != nil,
                onSelect: { source in
                    pendingAvatarSource = source
                    isShowingAvatarSourceSheet = false
                },
                onRemove: {
                    selectedAvatarImage = nil
                    avatarDidChange = true
                    isShowingAvatarSourceSheet = false
                }
            )
        }
        .fullScreenCover(item: $activeAvatarSource) { source in
            CameraImagePicker(sourceType: source.sourceType, image: $selectedAvatarImage)
                .ignoresSafeArea()
                .onDisappear {
                    if selectedAvatarImage != nil {
                        avatarDidChange = true
                    }
                }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.tagBackground)
                    .frame(width: 80, height: 80)
                Circle()
                    .fill(Color.primaryBlue.opacity(0.06))
                    .frame(width: 58, height: 58)
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.primaryBlue)
            }

            VStack(spacing: 6) {
                Text("Complete Your Profile")
                    .font(.pageTitle)
                    .foregroundStyle(Color.textPrimary)

                if let username = sessionStore.authUser?.username {
                    Text("Welcome, \(username)! Add a photo and tell the community about yourself.")
                        .font(.captionText)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                } else {
                    Text("Add a photo and tell the community about yourself.")
                        .font(.captionText)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        Button {
            isShowingAvatarSourceSheet = true
        } label: {
            VStack(spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    avatarPreview

                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.primaryBlue)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.phBackground, lineWidth: 2)
                        )
                }

                Text(avatarActionTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.primaryBlue)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var avatarActionTitle: String {
        if selectedAvatarImage != nil || currentAvatarURL != nil {
            return "Change Photo"
        }
        return "Add Photo"
    }

    private var currentAvatarURL: String? {
        sessionStore.authUser?.avatarUrlString
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let selectedAvatarImage {
            Image(uiImage: selectedAvatarImage)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(Circle())
        } else if avatarDidChange {
            Avatar(url: nil, size: .large)
        } else {
            Avatar(urlString: currentAvatarURL, size: .large)
        }
    }

    private func presentPendingAvatarSource() {
        guard let pendingAvatarSource else { return }
        self.pendingAvatarSource = nil

        DispatchQueue.main.async {
            activeAvatarSource = pendingAvatarSource
        }
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Bio")
                TextArea(
                    placeholder: "Tell plant lovers about yourself.",
                    text: $bio,
                    maxLength: 150
                )
            }

            AuthTextInput(
                label: "Location",
                placeholder: "Where are you growing plants?",
                text: $location,
                leadingIcon: "mappin.and.ellipse"
            )
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color.textPrimary)
    }

    // MARK: - Actions

    private var trimmedBio: String {
        bio.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedLocation: String {
        location.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasProfileChanges: Bool {
        avatarDidChange || !trimmedBio.isEmpty || !trimmedLocation.isEmpty
    }

    @MainActor
    private func handleContinue() async {
        UIApplication.shared.endEditing()

        guard hasProfileChanges else {
            onComplete()
            return
        }

        guard let username = sessionStore.authUser?.username else {
            onComplete()
            return
        }

        isSaving = true
        errorMessage = nil

        let avatarPayload: (base64: String?, includesAvatar: Bool) = {
            guard avatarDidChange else { return (nil, false) }
            if let selectedAvatarImage {
                guard let encoded = ProfileImageEncoder.jpegBase64(from: selectedAvatarImage) else {
                    return (nil, true)
                }
                return (encoded, true)
            }
            return (nil, true)
        }()

        if avatarDidChange, selectedAvatarImage != nil, avatarPayload.base64 == nil {
            errorMessage = "The selected photo is too large to upload. Try a smaller image."
            isSaving = false
            return
        }

        let request = ProfileUpdateRequest(
            username: username,
            name: nil,
            bio: trimmedBio,
            country: trimmedLocation,
            avatarBase64: avatarPayload.base64,
            includesAvatar: avatarPayload.includesAvatar
        )

        do {
            _ = try await authAPIService.updateProfile(request)
            isSaving = false
            onComplete()
        } catch let error as NetworkError {
            isSaving = false
            switch error {
            case let .httpError(_, message):
                errorMessage = message ?? "Unable to save profile."
            default:
                errorMessage = "Unable to save profile."
            }
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Avatar source sheet

private struct CompleteProfileAvatarSourceSheet: View {
    @Environment(\.dismiss) private var dismiss

    let sources: [ProfileAvatarSource]
    let canRemovePhoto: Bool
    let onSelect: (ProfileAvatarSource) -> Void
    let onRemove: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(sources) { source in
                        Button {
                            onSelect(source)
                        } label: {
                            Label(source.label, systemImage: source.iconName)
                                .foregroundStyle(Color.textPrimary)
                        }
                    }

                    if canRemovePhoto {
                        Button(role: .destructive) {
                            onRemove()
                        } label: {
                            Label("Remove Photo", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
    }

    private var sheetHeight: CGFloat {
        let rowHeight: CGFloat = 52
        let baseHeight: CGFloat = 120
        let removeRow = canRemovePhoto ? rowHeight : 0
        return baseHeight + CGFloat(sources.count) * rowHeight + removeRow
    }
}

private extension ProfileAvatarSource {
    var iconName: String {
        switch self {
        case .camera: return "camera.fill"
        case .photoLibrary: return "photo.on.rectangle.angled"
        }
    }
}
