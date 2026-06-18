import Foundation
import UIKit

// MARK: - Persistence models

private struct ChatOwnerProfile: Codable, Equatable {
    let userID: String
    let username: String
    let avatarUrlString: String?

    static let guest = ChatOwnerProfile(userID: "guest", username: "You", avatarUrlString: nil)

    init(userID: String, username: String, avatarUrlString: String?) {
        self.userID = userID
        self.username = username
        self.avatarUrlString = avatarUrlString
    }

    init(authUser: AuthUser) {
        self.init(
            userID: authUser.id.uuidString,
            username: authUser.username,
            avatarUrlString: authUser.avatarUrlString
        )
    }
}

private struct PersistedChatSnapshot: Codable {
    var owner: ChatOwnerProfile
    var threads: [ChatRowData]
    var messagesByChatID: [String: [PersistedMessage]]

    private enum CodingKeys: String, CodingKey {
        case owner
        case threads
        case messagesByChatID
    }

    init(owner: ChatOwnerProfile, threads: [ChatRowData], messagesByChatID: [String: [PersistedMessage]]) {
        self.owner = owner
        self.threads = threads
        self.messagesByChatID = messagesByChatID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        owner = (try? container.decode(ChatOwnerProfile.self, forKey: .owner)) ?? .guest
        threads = try container.decode([ChatRowData].self, forKey: .threads)
        messagesByChatID = try container.decode([String: [PersistedMessage]].self, forKey: .messagesByChatID)
    }
}

private struct PersistedMessage: Codable, Identifiable {
    let id: String
    let content: PersistedMessageContent
    let isSelf: Bool
    let createdAt: Date
}

private enum PersistedMessageContent: Codable, Equatable {
    case text(String)
    case image(filename: String)
    case audio(filename: String, duration: TimeInterval)
}

// MARK: - LocalChatStore

/// Local-only chat persistence for V1. Replace with API-backed storage later.
@Observable
final class LocalChatStore {
    static let shared = LocalChatStore()

    private(set) var threads: [ChatRowData] = []

    private var messagesByChatID: [String: [PersistedMessage]] = [:]
    private var activeOwner: ChatOwnerProfile = .guest
    private let defaultsKeyPrefix = "com.planthub.localChat.snapshot.v3"
    private let fileManager = FileManager.default

    private init() {
        if let authUser = UserSessionStore.shared.authUser {
            syncCurrentUser(authUser)
        }
    }

    func syncCurrentUser(_ user: AuthUser) {
        let nextOwner = ChatOwnerProfile(authUser: user)

        if activeOwner.userID == nextOwner.userID {
            activeOwner = nextOwner
            if threads.isEmpty && messagesByChatID.isEmpty {
                loadOrSeedSnapshotForActiveOwner()
            } else {
                hydrateMissingThreadAvatarsIfNeeded()
                migrateLegacyPersonalizedMockMessagesIfNeeded()
                persist()
            }
            return
        }

        activeOwner = nextOwner
        threads = []
        messagesByChatID = [:]
        loadOrSeedSnapshotForActiveOwner()
    }

    func messages(for chatID: String) -> [MessageBubbleData] {
        ensureActiveOwnerSyncedFromSession()
        return (messagesByChatID[chatID] ?? []).map {
            $0.toBubbleData(imagesDirectory: imagesDirectory, audioDirectory: audioDirectory)
        }
    }

    func canSendMessage(chatID: String) -> Bool {
        ensureActiveOwnerSyncedFromSession()

        // Seeded demo conversations should stay unrestricted.
        if Self.isMockChatID(chatID) {
            return true
        }

        let messages = messagesByChatID[chatID] ?? []
        guard !messages.isEmpty else { return true }

        let latestSelf = messages
            .filter(\.isSelf)
            .map(\.createdAt)
            .max()
        guard let latestSelf else { return true }

        let latestIncoming = messages
            .filter { !$0.isSelf }
            .map(\.createdAt)
            .max()
        guard let latestIncoming else { return false }

        return latestIncoming > latestSelf
    }

    func ensureThread(for chat: ChatItem) {
        ensureActiveOwnerSyncedFromSession()
        if let existingIndex = threads.firstIndex(where: { $0.id == chat.id }) {
            if threads[existingIndex].avatarURL == nil, let avatarURL = chat.avatarURL {
                threads[existingIndex].avatarURL = avatarURL
                persist()
            }
            return
        }

        threads.append(
            ChatRowData(
                id: chat.id,
                username: chat.username,
                avatarURL: chat.avatarURL,
                lastMessage: "",
                lastMessageAt: Date(),
                unreadCount: 0,
                isMutualFollow: chat.isMutualFollow
            )
        )
        messagesByChatID[chat.id] = []
        sortThreads()
        persist()
    }

    func sendText(chatID: String, text: String, chat: ChatItem) {
        ensureActiveOwnerSyncedFromSession()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        ensureThread(for: chat)

        let message = PersistedMessage(
            id: UUID().uuidString,
            content: .text(trimmed),
            isSelf: true,
            createdAt: Date()
        )

        append(message, to: chatID)
        updateThreadPreview(chatID: chatID, preview: trimmed, at: message.createdAt, isIncoming: false)
        persist()
    }

    func sendVoice(chatID: String, audioURL: URL, duration: TimeInterval, chat: ChatItem) {
        ensureActiveOwnerSyncedFromSession()
        ensureThread(for: chat)

        let messageID = UUID().uuidString
        guard let filename = saveAudio(from: audioURL, messageID: messageID) else { return }

        let message = PersistedMessage(
            id: messageID,
            content: .audio(filename: filename, duration: duration),
            isSelf: true,
            createdAt: Date()
        )

        append(message, to: chatID)
        updateThreadPreview(chatID: chatID, preview: "Voice message", at: message.createdAt, isIncoming: false)
        persist()
    }

    func sendImage(chatID: String, image: UIImage, chat: ChatItem) {
        ensureActiveOwnerSyncedFromSession()
        ensureThread(for: chat)

        let messageID = UUID().uuidString
        guard let filename = saveImage(image, messageID: messageID) else { return }

        let message = PersistedMessage(
            id: messageID,
            content: .image(filename: filename),
            isSelf: true,
            createdAt: Date()
        )

        append(message, to: chatID)
        updateThreadPreview(chatID: chatID, preview: "Photo", at: message.createdAt, isIncoming: false)
        persist()
    }

    func markAsRead(chatID: String) {
        ensureActiveOwnerSyncedFromSession()
        guard let index = threads.firstIndex(where: { $0.id == chatID }) else { return }
        guard threads[index].unreadCount > 0 else { return }

        threads[index].unreadCount = 0
        persist()
    }

    func deleteThread(chatID: String) {
        ensureActiveOwnerSyncedFromSession()
        if let messages = messagesByChatID[chatID] {
            messages.compactMap(\.imageFilename).forEach(deleteImageFile)
            messages.compactMap(\.audioFilename).forEach(deleteAudioFile)
        }

        threads.removeAll { $0.id == chatID }
        messagesByChatID[chatID] = nil
        persist()
    }

    func clearAll() {
        ensureActiveOwnerSyncedFromSession()
        let allMessages = messagesByChatID.values.flatMap { $0 }
        allMessages.compactMap(\.imageFilename).forEach(deleteImageFile)
        allMessages.compactMap(\.audioFilename).forEach(deleteAudioFile)

        threads = []
        messagesByChatID = [:]
        activeOwner = .guest
        clearAllSnapshots()

        for dir in [rootImagesDirectory, rootAudioDirectory] where fileManager.fileExists(atPath: dir.path) {
            try? fileManager.removeItem(at: dir)
        }
    }

    // MARK: Private

    private var currentDefaultsKey: String {
        "\(defaultsKeyPrefix).\(activeOwner.userID)"
    }

    private var rootImagesDirectory: URL {
        let base = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ChatImages", isDirectory: true)
    }

    private var imagesDirectory: URL {
        let directory = rootImagesDirectory.appendingPathComponent(activeOwner.userID, isDirectory: true)

        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory
    }

    private var rootAudioDirectory: URL {
        let base = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ChatAudio", isDirectory: true)
    }

    private var audioDirectory: URL {
        let directory = rootAudioDirectory.appendingPathComponent(activeOwner.userID, isDirectory: true)

        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory
    }

    private func append(_ message: PersistedMessage, to chatID: String) {
        var messages = messagesByChatID[chatID] ?? []
        messages.append(message)
        messagesByChatID[chatID] = messages
    }

    private func updateThreadPreview(
        chatID: String,
        preview: String,
        at date: Date,
        isIncoming: Bool
    ) {
        guard let index = threads.firstIndex(where: { $0.id == chatID }) else { return }

        threads[index].lastMessage = preview
        threads[index].lastMessageAt = date

        if isIncoming {
            threads[index].unreadCount += 1
        }

        sortThreads()
    }

    private func sortThreads() {
        threads.sort { $0.lastMessageAt > $1.lastMessageAt }
    }

    private func saveImage(_ image: UIImage, messageID: String) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }

        let filename = "\(messageID).jpg"
        let url = imagesDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: url, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    private func deleteImageFile(_ filename: String) {
        let url = imagesDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: url)
    }

    private func saveAudio(from sourceURL: URL, messageID: String) -> String? {
        let filename = "\(messageID).m4a"
        let destURL = audioDirectory.appendingPathComponent(filename)

        do {
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destURL)
            try? fileManager.removeItem(at: sourceURL)
            return filename
        } catch {
            return nil
        }
    }

    private func deleteAudioFile(_ filename: String) {
        let url = audioDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: url)
    }

    private func ensureActiveOwnerSyncedFromSession() {
        guard activeOwner == .guest, let authUser = UserSessionStore.shared.authUser else { return }
        syncCurrentUser(authUser)
    }

    private func loadOrSeedSnapshotForActiveOwner() {
        guard let data = UserDefaults.standard.data(forKey: currentDefaultsKey),
              let snapshot = try? JSONDecoder().decode(PersistedChatSnapshot.self, from: data)
        else {
            seedInitialMockDataIfNeeded()
            return
        }

        guard snapshot.owner.userID == activeOwner.userID || snapshot.owner == .guest else {
            seedInitialMockDataIfNeeded()
            return
        }

        if snapshot.threads.isEmpty && snapshot.messagesByChatID.isEmpty {
            seedInitialMockDataIfNeeded()
            return
        }

        threads = snapshot.threads
        messagesByChatID = snapshot.messagesByChatID
        hydrateMissingThreadAvatarsIfNeeded()
        migrateLegacyPersonalizedMockMessagesIfNeeded()
        sortThreads()
    }

    private func persist() {
        let snapshot = PersistedChatSnapshot(
            owner: activeOwner,
            threads: threads,
            messagesByChatID: messagesByChatID
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: currentDefaultsKey)
    }

    private func seedInitialMockDataIfNeeded() {
        guard threads.isEmpty, messagesByChatID.isEmpty else { return }
        let snapshot = Self.mockSeedSnapshot(owner: activeOwner, referenceDate: Date())
        guard !snapshot.threads.isEmpty else { return }

        threads = snapshot.threads
        messagesByChatID = snapshot.messagesByChatID
        sortThreads()
        persist()
    }

    private static func mockSeedSnapshot(owner: ChatOwnerProfile, referenceDate: Date) -> PersistedChatSnapshot {
        let seededPosts = seedPostsForMockChats()
        var seededThreads: [ChatRowData] = []
        var seededMessages: [String: [PersistedMessage]] = [:]

        for (index, post) in seededPosts.enumerated() {
            let chatID = "chat-\(post.author.id)"
            let scenario = mockScenario(forSeedIndex: index)
            let anchorDate = referenceDate.addingTimeInterval(TimeInterval(-9_750 - (index * 2_400)))
            let conversation = mockConversation(
                for: post,
                scenario: scenario,
                anchorDate: anchorDate
            )
            let lastMessage = conversation.last?.previewText ?? ""
            let lastMessageAt = conversation.last?.createdAt ?? referenceDate
            let unreadCount = (index == 0) ? 2 : ((index == 1) ? 1 : 0)

            seededThreads.append(
                ChatRowData(
                    id: chatID,
                    username: post.author.username,
                    avatarURL: post.author.avatarUrlString.flatMap(URL.init(string:)),
                    lastMessage: lastMessage,
                    lastMessageAt: lastMessageAt,
                    unreadCount: unreadCount,
                    isMutualFollow: true
                )
            )
            seededMessages[chatID] = conversation
        }

        return PersistedChatSnapshot(
            owner: owner,
            threads: seededThreads,
            messagesByChatID: seededMessages
        )
    }

    static func mockChatCounterpartUserIDs(limit: Int = 4) -> [String] {
        seedPostsForMockChats(limit: limit).map(\.author.id)
    }

    /// Whether a thread belongs to the seeded demo chat counterparts.
    static func isMockChatID(_ chatID: String) -> Bool {
        guard let userID = userID(fromThreadID: chatID) else { return false }
        return mockChatCounterpartUserIDs().contains(userID)
    }

    private static func seedPostsForMockChats(limit: Int = 4) -> [SpecimenPost] {
        var selected: [SpecimenPost] = []
        var seenAuthors = Set<String>()

        for post in GardenHomeMockData.posts where seenAuthors.insert(post.author.id).inserted {
            selected.append(post)
            if selected.count == limit { break }
        }

        return selected
    }

    private static func mockConversation(
        for post: SpecimenPost,
        scenario: MockChatScenario,
        anchorDate: Date
    ) -> [PersistedMessage] {
        let (incoming1, outgoing, incoming2): (String, String, String)

        switch scenario {
        case .careTips:
            incoming1 = "Your \(post.plantName) care routine helped me stabilize leaf curl this week."
            outgoing = "Glad it helped. Did you increase humidity or adjust watering first?"
            incoming2 = "I increased humidity first, then reduced watering a bit. It recovered quickly."

        case .repotting:
            incoming1 = "I repotted my \(post.plantName) yesterday and the roots looked healthier than expected."
            outgoing = "Nice timing. Did you keep it in bright indirect light after repotting?"
            incoming2 = "Yes, and I skipped fertilizer for now. No transplant shock so far."

        case .pests:
            incoming1 = "Small pest spots appeared on my \(post.plantName), but your checklist was useful."
            outgoing = "Great catch. Did you isolate it and wipe both sides of the leaves?"
            incoming2 = "I did both and started a weekly check. New leaves look clean now."

        case .bloomingProgress:
            incoming1 = "My \(post.plantName) opened a new bloom this morning after the recent warm week."
            outgoing = "That is exciting. How many hours of light is it getting right now?"
            incoming2 = "Around six bright hours daily. I can already see the next bud forming."
        }

        return [
            PersistedMessage(
                id: "\(post.id)-m1",
                content: .text(incoming1),
                isSelf: false,
                createdAt: anchorDate.addingTimeInterval(-1_050)
            ),
            PersistedMessage(
                id: "\(post.id)-m2",
                content: .text(outgoing),
                isSelf: true,
                createdAt: anchorDate.addingTimeInterval(-570)
            ),
            PersistedMessage(
                id: "\(post.id)-m3",
                content: .text(incoming2),
                isSelf: false,
                createdAt: anchorDate
            )
        ]
    }

    private static func mockScenario(forSeedIndex index: Int) -> MockChatScenario {
        let scenarios = MockChatScenario.allCases
        return scenarios[index % scenarios.count]
    }

    private func clearAllSnapshots() {
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix(defaultsKeyPrefix) {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func hydrateMissingThreadAvatarsIfNeeded() {
        var didMutate = false

        for index in threads.indices where threads[index].avatarURL == nil {
            guard let fallbackAvatarURL = Self.fallbackAvatarURL(forThreadID: threads[index].id) else { continue }
            threads[index].avatarURL = fallbackAvatarURL
            didMutate = true
        }

        if didMutate {
            persist()
        }
    }

    private static func fallbackAvatarURL(forThreadID threadID: String) -> URL? {
        guard let userID = userID(fromThreadID: threadID) else { return nil }

        if let bundledAvatar = CommunityAvatarAssets.avatarURL(forUserId: userID) {
            return bundledAvatar
        }

        guard let avatarString = GardenHomeMockData.posts
            .first(where: { $0.author.id == userID })?
            .author
            .avatarUrlString else {
            return nil
        }
        return URL(string: avatarString)
    }

    private static func userID(fromThreadID threadID: String) -> String? {
        guard threadID.hasPrefix("chat-") else { return nil }
        return String(threadID.dropFirst(5))
    }

    private func migrateLegacyPersonalizedMockMessagesIfNeeded() {
        var didMutate = false
        var migratedMap: [String: [PersistedMessage]] = [:]

        for (chatID, messages) in messagesByChatID {
            let counterpartID = Self.userID(fromThreadID: chatID)
            let relatedPost = counterpartID.flatMap { userID in
                GardenHomeMockData.posts.first(where: { $0.author.id == userID })
            }
            let threadIndex = threads.firstIndex(where: { $0.id == chatID }) ?? 0

            if let relatedPost,
               Self.isSeedOnlyMockConversation(messages, postID: relatedPost.id) {
                let seededOrder = Self.mockChatCounterpartUserIDs()
                let scenarioIndex = counterpartID.flatMap { seededOrder.firstIndex(of: $0) } ?? threadIndex
                let scenario = Self.mockScenario(forSeedIndex: scenarioIndex)
                let refreshed = Self.mockConversation(
                    for: relatedPost,
                    scenario: scenario,
                    anchorDate: messages.last?.createdAt ?? Date()
                )
                migratedMap[chatID] = refreshed
                didMutate = true

                if threads.indices.contains(threadIndex) {
                    threads[threadIndex].lastMessage = refreshed.last?.previewText ?? ""
                    threads[threadIndex].lastMessageAt = refreshed.last?.createdAt ?? Date()
                    if threads[threadIndex].unreadCount > 2 {
                        threads[threadIndex].unreadCount = 2
                    }
                }
                continue
            }

            var migratedMessages: [PersistedMessage] = []
            var chatMutated = false

            for message in messages {
                guard case let .text(text) = message.content,
                      let genericText = Self.genericizeLegacyMockText(text) else {
                    migratedMessages.append(message)
                    continue
                }

                migratedMessages.append(
                    PersistedMessage(
                        id: message.id,
                        content: .text(genericText),
                        isSelf: message.isSelf,
                        createdAt: message.createdAt
                    )
                )
                chatMutated = true
            }

            migratedMap[chatID] = migratedMessages
            didMutate = didMutate || chatMutated
        }

        guard didMutate else { return }
        messagesByChatID = migratedMap
        sortThreads()
        persist()
    }

    private static func isSeedOnlyMockConversation(_ messages: [PersistedMessage], postID: String) -> Bool {
        guard !messages.isEmpty else { return false }
        let seedPrefix = "\(postID)-m"
        return messages.allSatisfy { $0.id.hasPrefix(seedPrefix) }
    }

    private static func genericizeLegacyMockText(_ text: String) -> String? {
        if text.contains("was super helpful.") {
            return "That update was really helpful."
        }

        if text.contains("Ping me if your next") && text.contains("leaf starts unfurling.") {
            return "Keep me posted when your next leaf starts unfurling."
        }

        let savedPrefix = "Saved this tip from your post: \""
        if text.hasPrefix(savedPrefix), text.hasSuffix("\".") {
            let excerptStart = text.index(text.startIndex, offsetBy: savedPrefix.count)
            let excerptEnd = text.index(text.endIndex, offsetBy: -2)
            guard excerptStart <= excerptEnd else { return nil }
            let excerpt = String(text[excerptStart..<excerptEnd])
            return "I noted this from your post: \"\(excerpt)\"."
        }

        let marker = ", and I saved this part: \""
        guard text.hasPrefix("I'm "),
              let markerRange = text.range(of: marker),
              text.hasSuffix("\".") else {
            return nil
        }

        let excerptStart = markerRange.upperBound
        let excerptEnd = text.index(text.endIndex, offsetBy: -2)
        guard excerptStart <= excerptEnd else { return nil }
        let excerpt = String(text[excerptStart..<excerptEnd])
        return "I noted this from your post: \"\(excerpt)\"."
    }
}

private enum MockChatScenario: CaseIterable {
    case careTips
    case repotting
    case pests
    case bloomingProgress
}

private extension PersistedMessage {
    var imageFilename: String? {
        if case let .image(filename) = content { return filename }
        return nil
    }

    var audioFilename: String? {
        if case let .audio(filename, _) = content { return filename }
        return nil
    }

    var previewText: String {
        switch content {
        case let .text(text): return text
        case .image: return "Photo"
        case .audio: return "Voice message"
        }
    }

    func toBubbleData(imagesDirectory: URL, audioDirectory: URL) -> MessageBubbleData {
        switch content {
        case let .text(text):
            return MessageBubbleData(id: id, content: .text(text), isSelf: isSelf, createdAt: createdAt)

        case let .image(filename):
            let fileURL = imagesDirectory.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return MessageBubbleData(id: id, content: .localImage(fileURL), isSelf: isSelf, createdAt: createdAt)
            }
            return MessageBubbleData(id: id, content: .text("Photo unavailable"), isSelf: isSelf, createdAt: createdAt)

        case let .audio(filename, duration):
            let fileURL = audioDirectory.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return MessageBubbleData(id: id, content: .voice(fileURL, duration: duration), isSelf: isSelf, createdAt: createdAt)
            }
            return MessageBubbleData(id: id, content: .text("Voice message unavailable"), isSelf: isSelf, createdAt: createdAt)
        }
    }
}
