import SwiftUI
import UIKit

// MARK: - EditProfileView

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.authAPIService) private var authAPIService

    let initialProfile: ProfileHeaderData
    var onSave: (ProfileHeaderData) -> Void = { _ in }

    @State private var displayName: String
    @State private var bio: String
    @State private var country: String
    @State private var selectedAvatarImage: UIImage?
    @State private var avatarDidChange = false
    @State private var isShowingAvatarSourceSheet = false
    @State private var pendingAvatarSource: ProfileAvatarSource?
    @State private var activeAvatarSource: ProfileAvatarSource?
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        initialProfile: ProfileHeaderData,
        onSave: @escaping (ProfileHeaderData) -> Void = { _ in }
    ) {
        self.initialProfile = initialProfile
        self.onSave = onSave
        _displayName = State(initialValue: initialProfile.username)
        _bio = State(initialValue: initialProfile.bio)
        _country = State(initialValue: initialProfile.country)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                avatarSection
                formSection

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.hotCoral)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .background(Color.phBackground)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await saveProfile() }
                } label: {
                    Text("Save")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(canSave && !isSaving ? Color.primaryBlue : Color.primaryBlue.opacity(0.4))
                .disabled(!canSave || isSaving)
            }
        }
        .blockingLoadingOverlay(isPresented: isSaving, message: "Saving…")
        .sheet(isPresented: $isShowingAvatarSourceSheet, onDismiss: presentPendingAvatarSource) {
            ProfileAvatarSourceSheet(
                sources: ProfileAvatarSource.availableSources,
                canRemovePhoto: selectedAvatarImage != nil || initialProfile.avatarUrlString != nil,
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

    // MARK: - Sections

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

                Text("Change Photo")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.primaryBlue)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func presentPendingAvatarSource() {
        guard let pendingAvatarSource else { return }
        self.pendingAvatarSource = nil

        // Wait for the sheet to finish dismissing before presenting the picker.
        DispatchQueue.main.async {
            activeAvatarSource = pendingAvatarSource
        }
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
            Avatar(urlString: initialProfile.avatarUrlString, size: .large)
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Name")
                TextInput(
                    placeholder: "Your display name",
                    text: $displayName,
                    errorMessage: displayNameError
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Bio")
                TextArea(
                    placeholder: "Tell plant lovers about yourself.",
                    text: $bio,
                    maxLength: 150
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Country")
                TextInput(
                    placeholder: "Where are you growing plants?",
                    text: $country
                )
            }
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.textSecondary)
    }

    // MARK: - Validation / Save

    private var trimmedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedBio: String {
        bio.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedCountry: String {
        country.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayNameError: String? {
        guard !trimmedDisplayName.isEmpty else { return nil }
        if trimmedDisplayName.count > 30 { return "Name must be 30 characters or fewer." }
        return nil
    }

    private var canSave: Bool {
        !trimmedDisplayName.isEmpty && displayNameError == nil
    }

    @MainActor
    private func saveProfile() async {
        guard canSave else { return }

        UIApplication.shared.endEditing()
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
            username: nil,
            name: trimmedDisplayName,
            bio: trimmedBio,
            country: trimmedCountry,
            avatarBase64: avatarPayload.base64,
            includesAvatar: avatarPayload.includesAvatar
        )

        do {
            let updatedUser = try await authAPIService.updateProfile(request)
            onSave(updatedUser.profileHeaderData)
            dismiss()
        } catch let error as NetworkError {
            switch error {
            case let .httpError(_, message):
                errorMessage = message ?? "Unable to save profile."
            default:
                errorMessage = "Unable to save profile."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}

// MARK: - Avatar source sheet

private struct ProfileAvatarSourceSheet: View {
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
