import SwiftUI
import UIKit

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
    @State private var isVoiceInputMode = false
    @State private var isPressingHoldButton = false
    @State private var isRecordingActive = false
    @State private var isCancelPending = false
    @State private var holdToRecordTask: Task<Void, Never>?
    @State private var micBlink = false
    @State private var showMicPermissionAlert = false

    private let holdToRecordDelayNanoseconds: UInt64 = 250_000_000
    private let cancelSwipeThreshold: CGFloat = -60

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
        .onChange(of: isWaitingForReply) { _, isWaiting in
            if isWaiting {
                exitVoiceInputMode()
            }
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty {
                    EmptyStateView(
                        systemImage: "tree",
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
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "clock.badge.exclamationmark.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.savedAmber)

            Text("One message sent. Wait for \(chat.username) to reply before sending another.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.surfaceAmber)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.savedAmber.opacity(0.25))
                .frame(height: 1)
        }
    }

    private var waitingForReplyInputNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "paperplane.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.savedAmber)

            VStack(alignment: .leading, spacing: 6) {
                Text("Waiting for a reply")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Text("You can only send one message until \(chat.username) responds. Messaging will unlock after they reply.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceAmber)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.savedAmber.opacity(0.35), lineWidth: 1)
        )
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            if isWaitingForReply {
                waitingForReplyInputNotice
            } else {
                if isRecordingActive {
                    recordingHintBanner
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Group {
                    if isVoiceInputMode {
                        voiceInputBar
                    } else {
                        normalInputBar
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.phBackground)
        .overlay(alignment: .top) { Divider() }
        .animation(.easeInOut(duration: 0.22), value: isVoiceInputMode)
        .animation(.easeInOut(duration: 0.18), value: isRecordingActive)
        .animation(.easeInOut(duration: 0.15), value: isCancelPending)
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
                placeholder: "Message as \(session.authUser?.username ?? "you")...",
                text: $draft,
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
                Button {
                    enterVoiceInputMode()
                } label: {
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

    // MARK: Voice input bar

    private var voiceInputBar: some View {
        HStack(spacing: 10) {
            Avatar(urlString: session.authUser?.avatarUrlString, size: .small)

            Button {
                isShowingImagePicker = true
            } label: {
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .foregroundStyle(canComposeMessage ? Color.primaryBlue : Color.textSecondary)
            }
            .disabled(!canComposeMessage || isRecordingActive)

            holdToTalkButton

            Button {
                exitVoiceInputMode()
            } label: {
                Image(systemName: "keyboard")
                    .font(.system(size: 20))
                    .foregroundStyle(canComposeMessage ? Color.primaryBlue : Color.textSecondary)
            }
            .disabled(!canComposeMessage || isRecordingActive)
        }
    }

    private var holdToTalkButton: some View {
        Text(holdToTalkTitle)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(holdToTalkForeground)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(holdToTalkBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(holdToTalkBorder, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(isPressingHoldButton ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.12), value: isPressingHoldButton)
            .gesture(holdToTalkGesture)
            .opacity(canComposeMessage ? 1 : 0.5)
            .allowsHitTesting(canComposeMessage)
    }

    private var holdToTalkTitle: String {
        if isRecordingActive {
            return isCancelPending ? "Release to cancel" : "Release to send"
        }
        if isPressingHoldButton {
            return "Keep holding..."
        }
        return "Hold to Talk"
    }

    private var holdToTalkForeground: Color {
        if isRecordingActive {
            return isCancelPending ? Color.hotCoral : .white
        }
        return Color.textPrimary
    }

    private var holdToTalkBackground: Color {
        if isRecordingActive {
            return isCancelPending ? Color.hotCoral.opacity(0.14) : Color.primaryBlue
        }
        if isPressingHoldButton {
            return Color.primaryBlue.opacity(0.08)
        }
        return Color.phSurface
    }

    private var holdToTalkBorder: Color {
        if isRecordingActive {
            return isCancelPending ? Color.hotCoral : Color.primaryBlue
        }
        return isPressingHoldButton ? Color.primaryBlue : Color.phBorder
    }

    private var holdToTalkGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard canComposeMessage else { return }

                if !isPressingHoldButton {
                    isPressingHoldButton = true
                    scheduleHoldToRecord()
                }

                if isRecordingActive {
                    isCancelPending = value.translation.height < cancelSwipeThreshold
                }
            }
            .onEnded { value in
                holdToRecordTask?.cancel()
                holdToRecordTask = nil

                let shouldCancel = isRecordingActive && value.translation.height < cancelSwipeThreshold
                finishHoldToTalk(shouldSend: isRecordingActive && !shouldCancel)

                isPressingHoldButton = false
                isCancelPending = false
            }
    }

    // MARK: Recording hint

    private var recordingHintBanner: some View {
        HStack(spacing: 10) {
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

            Text(isCancelPending ? "Release to cancel" : "Slide up to cancel")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isCancelPending ? Color.hotCoral : Color.textSecondary)

            recordingWaveform
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.phSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.bottom, 8)
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

    private func enterVoiceInputMode() {
        UIApplication.shared.endEditing()
        withAnimation {
            isVoiceInputMode = true
        }
    }

    private func exitVoiceInputMode() {
        holdToRecordTask?.cancel()
        holdToRecordTask = nil

        if isRecordingActive {
            cancelVoiceRecording()
        }

        isPressingHoldButton = false
        isCancelPending = false

        withAnimation {
            isVoiceInputMode = false
        }
    }

    private func scheduleHoldToRecord() {
        holdToRecordTask?.cancel()
        holdToRecordTask = Task {
            try? await Task.sleep(nanoseconds: holdToRecordDelayNanoseconds)
            guard !Task.isCancelled, isPressingHoldButton else { return }

            await MainActor.run {
                guard isPressingHoldButton, !isRecordingActive else { return }
                Task { await beginHoldToRecord() }
            }
        }
    }

    @MainActor
    private func beginHoldToRecord() async {
        guard canComposeMessage, !isRecordingActive else { return }

        let started = await voiceRecorder.startRecording()
        if started {
            withAnimation {
                isRecordingActive = true
            }
        } else {
            isPressingHoldButton = false
            showMicPermissionAlert = true
        }
    }

    private func finishHoldToTalk(shouldSend: Bool) {
        guard isRecordingActive else { return }

        if shouldSend {
            sendVoiceRecording()
        } else {
            cancelVoiceRecording()
        }
    }

    private func cancelVoiceRecording() {
        voiceRecorder.cancelRecording()
        withAnimation {
            isRecordingActive = false
        }
    }

    private func sendVoiceRecording() {
        guard let audioURL = voiceRecorder.stopRecording() else {
            withAnimation { isRecordingActive = false }
            return
        }

        let duration = voiceRecorder.duration > 0 ? voiceRecorder.duration : 1
        chatStore.sendVoice(chatID: chat.id, audioURL: audioURL, duration: duration, chat: normalizedChat)
        withAnimation { isRecordingActive = false }
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
