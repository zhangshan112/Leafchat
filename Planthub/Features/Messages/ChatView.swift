import SwiftUI

// MARK: - ChatItem

struct ChatItem: Identifiable, Hashable {
    let id: String
    let userId: String
    let username: String
    let avatarURL: URL?
    var isMutualFollow: Bool
}

// MARK: - ChatView

struct ChatView: View {
    let chat: ChatItem

    @Bindable private var chatStore = LocalChatStore.shared
    @ObservedObject private var session = UserSessionStore.shared
    @State private var messages: [MessageBubbleData] = []
    @State private var draft = ""
    @State private var pickedImages: [UIImage] = []
    @State private var isShowingImagePicker = false
    @State private var isShowingMenu = false
    @State private var isBlocked = false
    @State private var showBlockedAlert = false
    @State private var showReportedAlert = false

    // Voice recording
    @State private var voiceRecorder = VoiceRecordingService.shared
    @State private var isRecordingMode = false
    @State private var micBlink = false
    @State private var showMicPermissionAlert = false

    private var canUseChat: Bool {
        chat.isMutualFollow && !isBlocked
    }

    private var canComposeMessage: Bool {
        canUseChat && chatStore.canSendMessage(chatID: chat.id)
    }

    private var isWaitingForReply: Bool {
        canUseChat && !chatStore.canSendMessage(chatID: chat.id)
    }

    private var canSendText: Bool {
        canComposeMessage && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var counterpartAvatarURL: URL? {
        chat.avatarURL ?? CommunityAvatarAssets.avatarURL(forUserId: chat.userId)
    }

    private var normalizedChat: ChatItem {
        ChatItem(
            id: chat.id,
            userId: chat.userId,
            username: chat.username,
            avatarURL: counterpartAvatarURL,
            isMutualFollow: chat.isMutualFollow
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if !chat.isMutualFollow {
                permissionBanner
            }

            if isBlocked {
                blockedBanner
            }

            if isWaitingForReply {
                waitingForReplyBanner
            }

            messageList

            inputBar
        }
        .background(Color.phBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                NavigationLink {
                    UserProfileView(userId: chat.userId)
                } label: {
                    HStack(spacing: 8) {
                        Avatar(url: counterpartAvatarURL, size: .small)
                        Text(chat.username)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                    }
                }
                .buttonStyle(.plain)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isShowingMenu = true
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Color.textPrimary)
                }
            }
        }
        .confirmationDialog("Chat Options", isPresented: $isShowingMenu, titleVisibility: .visible) {
            NavigationLink("View Profile") {
                UserProfileView(userId: chat.userId)
            }
            Button("Block User", role: .destructive) {
                isBlocked = true
                showBlockedAlert = true
            }
            Button("Report User", role: .destructive) {
                showReportedAlert = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $isShowingImagePicker) {
            NavigationStack {
                ImagePicker(images: $pickedImages, maxCount: 1)
                    .navigationTitle("Send Photo")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                pickedImages = []
                                isShowingImagePicker = false
                            }
                            .foregroundStyle(Color.primaryBlue)
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Send") {
                                sendImage()
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.primaryBlue)
                            .disabled(pickedImages.isEmpty)
                        }
                    }
            }
        }
        .alert("User Blocked", isPresented: $showBlockedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You will no longer receive messages from this user.")
        }
        .alert("Report Sent", isPresented: $showReportedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thanks for helping keep \(AppBranding.name) safe.")
        }
        .alert("Microphone Access Required", isPresented: $showMicPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow microphone access in Settings to send voice messages.")
        }
        .onAppear {
            if let authUser = session.authUser {
                chatStore.syncCurrentUser(authUser)
            }
            chatStore.ensureThread(for: normalizedChat)
            reloadMessages()
            chatStore.markAsRead(chatID: chat.id)
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty {
                    EmptyStateView(
                        systemImage: "leaf",
                        title: "Start a conversation",
                        description: "Send a message to \(chat.username)."
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(
                TapGesture().onEnded {
                    UIApplication.shared.endEditing()
                }
            )
            .onAppear { scrollToLatest(proxy) }
            .onChange(of: messages.count) { _, _ in
                scrollToLatest(proxy)
            }
        }
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        guard let lastId = messages.last?.id else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }

    // MARK: - Input

    private var permissionBanner: some View {
        Text("You can only chat with mutual followers.")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.primaryBlue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.tagBackground)
    }

    private var blockedBanner: some View {
        Text("You blocked this user. Unblock them in Settings to chat again.")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.phSurface)
    }

    private var waitingForReplyBanner: some View {
        Text("You can send one message at a time until they reply.")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.phSurface)
    }

    private var inputBar: some View {
        Group {
            if isRecordingMode {
                recordingBar
            } else {
                normalInputBar
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.phBackground)
        .overlay(alignment: .top) { Divider() }
        .animation(.easeInOut(duration: 0.22), value: isRecordingMode)
    }

    // MARK: Normal input bar

    private var normalInputBar: some View {
        HStack(spacing: 10) {
            Avatar(urlString: session.authUser?.avatarUrlString, size: .small)

            Button {
                isShowingImagePicker = true
            } label: {
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .foregroundStyle(canComposeMessage ? Color.primaryBlue : Color.textSecondary)
            }
            .disabled(!canComposeMessage)

            TextInput(
                placeholder: canComposeMessage
                    ? "Message as \(session.authUser?.username ?? "you")..."
                    : "Wait for their reply...",
                text: $draft,
                isDisabled: !canComposeMessage,
                onSubmit: sendText
            )

            if canSendText {
                Button { sendText() } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.primaryBlue)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Button { startVoiceRecording() } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(canComposeMessage ? Color.primaryBlue : Color.textSecondary)
                }
                .disabled(!canComposeMessage)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.25), value: canSendText)
    }

    // MARK: Recording bar

    private var recordingBar: some View {
        HStack(spacing: 12) {
            Button { cancelVoiceRecording() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Color.phSurface)
                    .clipShape(Circle())
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.likeRed)
                    .frame(width: 8, height: 8)
                    .opacity(micBlink ? 1 : 0.2)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: micBlink)
                    .onAppear { micBlink = true }
                    .onDisappear { micBlink = false }

                Text(formatDuration(voiceRecorder.duration))
                    .font(.system(size: 15, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                recordingWaveform
            }
            .frame(maxWidth: .infinity)

            Button { sendVoiceRecording() } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.primaryBlue)
                    .clipShape(Circle())
            }
        }
    }

    private var recordingWaveform: some View {
        let barCount = 14
        return HStack(spacing: 2.5) {
            ForEach(0..<barCount, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.primaryBlue.opacity(Double.random(in: 0.25...0.85)))
                    .frame(width: 2.5, height: CGFloat.random(in: 5...16))
            }
        }
        .frame(width: 56)
        .id(Int(voiceRecorder.duration * 3))
    }

    // MARK: - Actions

    private func reloadMessages() {
        messages = chatStore.messages(for: chat.id)
    }

    private func sendText() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canComposeMessage, !text.isEmpty else { return }

        chatStore.sendText(chatID: chat.id, text: text, chat: normalizedChat)
        draft = ""
        reloadMessages()
    }

    private func sendImage() {
        guard canComposeMessage, let image = pickedImages.first else { return }

        chatStore.sendImage(chatID: chat.id, image: image, chat: normalizedChat)
        pickedImages = []
        isShowingImagePicker = false
        reloadMessages()
    }

    // MARK: - Voice recording actions

    private func startVoiceRecording() {
        guard canComposeMessage else { return }

        Task {
            let started = await voiceRecorder.startRecording()
            await MainActor.run {
                if started {
                    withAnimation { isRecordingMode = true }
                } else {
                    showMicPermissionAlert = true
                }
            }
        }
    }

    private func cancelVoiceRecording() {
        voiceRecorder.cancelRecording()
        withAnimation { isRecordingMode = false }
    }

    private func sendVoiceRecording() {
        guard let audioURL = voiceRecorder.stopRecording() else {
            // Too short — silently return to normal mode
            withAnimation { isRecordingMode = false }
            return
        }

        let duration = voiceRecorder.duration > 0 ? voiceRecorder.duration : 1
        chatStore.sendVoice(chatID: chat.id, audioURL: audioURL, duration: duration, chat: normalizedChat)
        withAnimation { isRecordingMode = false }
        reloadMessages()
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = max(0, Int(duration))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

#Preview {
    NavigationStack {
        ChatView(
            chat: ChatItem(
                id: "c1",
                userId: "u1",
                username: "fernqueen",
                avatarURL: nil,
                isMutualFollow: true
            )
        )
    }
}
