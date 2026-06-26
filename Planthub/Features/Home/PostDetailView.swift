import SwiftUI
import UIKit

// MARK: - Post Detail Models

struct PostItem: Identifiable {
    let id: String
    let user: PostCardUser
    let imageAssetName: String?
    let localImage: UIImage?
    let content: String
    let createdAt: Date
    var likeCount: Int
    var commentCount: Int
    var isLiked: Bool
    var isSaved: Bool
    let plantTags: [PostPlantTag]

    init(
        id: String,
        user: PostCardUser,
        imageAssetName: String? = nil,
        localImage: UIImage? = nil,
        content: String,
        createdAt: Date,
        likeCount: Int,
        commentCount: Int,
        isLiked: Bool,
        isSaved: Bool,
        plantTags: [PostPlantTag]
    ) {
        self.id = id
        self.user = user
        self.imageAssetName = imageAssetName
        self.localImage = localImage
        self.content = content
        self.createdAt = createdAt
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.isLiked = isLiked
        self.isSaved = isSaved
        self.plantTags = plantTags
    }

    init(cardData: PostCardData) {
        id = cardData.id
        user = cardData.user
        imageAssetName = cardData.imageAssetName
        localImage = nil
        content = cardData.content
        createdAt = cardData.createdAt
        likeCount = cardData.likeCount
        commentCount = cardData.commentCount
        isLiked = cardData.isLiked
        isSaved = cardData.isSaved
        plantTags = cardData.plantTags
    }
}

private struct PostDetailComment: Identifiable {
    let id: String
    var comment: CommentCardData
    var replies: [CommentCardData]
    var isReplying = false
    var replyText = ""
}

private enum PostDetailReportContext: Identifiable {
    case post
    case comment(CommentCardData)

    var id: String {
        switch self {
        case .post:
            return "post"
        case .comment(let comment):
            return comment.id
        }
    }
}

// MARK: - PostDetailView

struct PostDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var session = UserSessionStore.shared
    @ObservedObject private var moderation = CommunityModerationStore.shared
    @ObservedObject private var feedStore = GardenFeedStore.shared

    @State private var post: PostItem
    @State private var comments: [PostDetailComment]
    @State private var newCommentText = ""
    @State private var likeScale: CGFloat = 1
    @State private var saveScale: CGFloat = 1
    @State private var reportContext: PostDetailReportContext?

    init(post: PostItem) {
        _post = State(initialValue: post)
        _comments = State(initialValue: Self.loadComments(for: post.id))
    }

    private static func loadComments(for postId: String) -> [PostDetailComment] {
        let store = LocalCommentStore.shared
        let moderation = CommunityModerationStore.shared

        var threads = GardenCommunityProfiles.commentThreads(for: postId).map { thread in
            var replies = thread.replies
            replies.append(
                contentsOf: store
                    .replies(for: postId, parentCommentId: thread.comment.id)
                    .map { $0.toCommentCardData() }
            )

            return PostDetailComment(
                id: thread.id,
                comment: thread.comment,
                replies: replies
            )
        }

        let userTopLevel = store.topLevelComments(for: postId).map { entry in
            PostDetailComment(
                id: entry.id,
                comment: entry.toCommentCardData(),
                replies: store
                    .replies(for: postId, parentCommentId: entry.id)
                    .map { $0.toCommentCardData() }
            )
        }

        return (userTopLevel + threads).compactMap { thread in
            guard !moderation.isCommentHidden(thread.comment.id) else { return nil }

            var visibleThread = thread
            visibleThread.replies = thread.replies.filter { !moderation.isCommentHidden($0.id) }
            return visibleThread
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                    postImage
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 14) {
                        actionBar(proxy: proxy)
                        contentText
                        tagList
                        commentsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .safeAreaInset(edge: .bottom) {
                inputBar
            }
            .background(Color.phBackground)
            .navigationTitle("Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if canReportPost {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            reportContext = .post
                        } label: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.accentBlack.opacity(0.55), in: Circle())
                        }
                        .accessibilityLabel("Report post")
                    }
                }
            }
            .sheet(item: $reportContext) { context in
                switch context {
                case .post:
                    ReportContentSheet(
                        title: "Report Post",
                        message: "Help keep \(AppBranding.name) safe. Reported posts are hidden from your feed immediately."
                    ) { submission in
                        moderation.reportPost(
                            id: post.id,
                            authorId: post.user.id,
                            authorUsername: post.user.username,
                            submission: submission
                        )
                        dismiss()
                    }
                case .comment(let comment):
                    ReportContentSheet(
                        title: "Report Comment",
                        message: "Help keep \(AppBranding.name) safe. Reported comments are hidden from this post immediately."
                    ) { submission in
                        moderation.reportComment(
                            id: comment.id,
                            postId: post.id,
                            authorId: comment.userId,
                            authorUsername: comment.username,
                            submission: submission
                        )
                        removeReportedComment(comment.id)
                    }
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onChange(of: moderation.isPostSuppressed(postId: post.id, authorId: post.user.id)) { _, isSuppressed in
                if isSuppressed { dismiss() }
            }
            .onAppear {
                syncSavedStateFromStore()
            }
        }
    }

    private var canReportPost: Bool {
        guard let currentUserId = session.authUser?.id.uuidString else { return true }
        return currentUserId != post.user.id
    }

    @ViewBuilder
    private var postImage: some View {
        if let assetName = post.imageAssetName {
            Image(assetName)
                .resizable()
                .scaledToFill()
                .mediaFill()
                .mediaContainer(aspectRatio: 4.0 / 5.0)
        } else if let localImage = post.localImage {
            Image(uiImage: localImage)
                .resizable()
                .scaledToFill()
                .mediaFill()
                .mediaContainer(aspectRatio: 4.0 / 5.0)
        }
    }

    // MARK: - Header

    private var header: some View {
        NavigationLink {
            UserProfileView(userId: post.user.id)
        } label: {
            HStack(spacing: 10) {
                Avatar(urlString: post.user.avatarUrlString, size: .medium)

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.user.username)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(post.createdAt.phRelative)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var contentText: some View {
        Text(post.content)
            .font(.system(size: 16))
            .foregroundStyle(Color.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var tagList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(post.plantTags) { tag in
                    PlantTagLink(name: tag.name)
                }
            }
        }
    }

    // MARK: - Actions

    private func actionBar(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 18) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    post.isLiked.toggle()
                    post.likeCount += post.isLiked ? 1 : -1
                    likeScale = 1.35
                }
                resetScale(\.likeScale)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: post.isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(post.isLiked ? .red : Color.textSecondary)
                        .scaleEffect(likeScale)
                    Text("\(post.likeCount)")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo("comments-section", anchor: .top)
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "message")
                    Text("\(post.commentCount)")
                        .font(.system(size: 14))
                }
                .foregroundStyle(Color.textSecondary)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.spring(response: 0.3)) {
                    feedStore.toggleSaved(post.id)
                    post.isSaved = feedStore.isSaved(post.id)
                    saveScale = 1.35
                }
                resetScale(\.saveScale)
            } label: {
                Image(systemName: post.isSaved ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(post.isSaved ? Color.primaryBlue : Color.textSecondary)
                    .scaleEffect(saveScale)
            }
            .buttonStyle(.plain)

            ShareLink(
                item: "Check out this \(AppBranding.name) post by \(post.user.username): \(post.content)"
            ) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()
        }
    }

    private func syncSavedStateFromStore() {
        post.isSaved = feedStore.isSaved(post.id)
    }

    private func resetScale(_ keyPath: WritableKeyPath<PostDetailView, CGFloat>) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3)) {
                switch keyPath {
                case \.likeScale:
                    likeScale = 1
                case \.saveScale:
                    saveScale = 1
                default:
                    break
                }
            }
        }
    }

    // MARK: - Comments

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Comments")
                .font(.sectionTitle)
                .foregroundStyle(Color.textPrimary)
                .id("comments-section")

            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(comments.indices, id: \.self) { index in
                    commentThread(index)
                    if index != comments.indices.last {
                        Divider().padding(.leading, 42)
                    }
                }
            }
        }
    }

    private func commentThread(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            CommentCard(
                comment: comments[index].comment,
                isCurrentUser: isCurrentUserComment(comments[index].comment),
                onLike: { toggleCommentLike(index) },
                onReply: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        comments[index].isReplying.toggle()
                    }
                },
                onReport: canReportComment(comments[index].comment)
                    ? { reportContext = .comment(comments[index].comment) }
                    : nil
            )

            if !comments[index].replies.isEmpty {
                VStack(spacing: 0) {
                    ForEach(comments[index].replies) { reply in
                        CommentCard(
                            comment: reply,
                            isCurrentUser: isCurrentUserComment(reply),
                            onReport: canReportComment(reply)
                                ? { reportContext = .comment(reply) }
                                : nil
                        )
                        .padding(.leading, 42)
                    }
                }
            }

            if comments[index].isReplying {
                HStack(spacing: 8) {
                    TextInput(
                        placeholder: "Add a reply...",
                        text: Binding(
                            get: { comments[index].replyText },
                            set: { comments[index].replyText = $0 }
                        )
                    )

                    Button {
                        sendReply(index)
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(Color.primaryBlue)
                    }
                    .disabled(comments[index].replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.leading, 42)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func toggleCommentLike(_ index: Int) {
        comments[index].comment.isLiked.toggle()
        comments[index].comment.likeCount += comments[index].comment.isLiked ? 1 : -1
    }

    private func isCurrentUserComment(_ comment: CommentCardData) -> Bool {
        session.authUser?.id.uuidString == comment.userId
    }

    private func canReportComment(_ comment: CommentCardData) -> Bool {
        !isCurrentUserComment(comment)
    }

    private func removeReportedComment(_ commentId: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if let index = comments.firstIndex(where: { $0.comment.id == commentId }) {
                let removedCount = 1 + comments[index].replies.count
                comments.remove(at: index)
                post.commentCount = max(0, post.commentCount - removedCount)
                return
            }

            for index in comments.indices {
                guard let replyIndex = comments[index].replies.firstIndex(where: { $0.id == commentId }) else {
                    continue
                }
                comments[index].replies.remove(at: replyIndex)
                post.commentCount = max(0, post.commentCount - 1)
                return
            }
        }
    }

    private func sendReply(_ index: Int) {
        let text = comments[index].replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let author = session.commentAuthor else { return }
        let entry = LocalCommentStore.shared.saveReply(
            postId: post.id,
            parentCommentId: comments[index].comment.id,
            author: author,
            content: text
        )
        let reply = entry.toCommentCardData()

        withAnimation(.easeInOut(duration: 0.2)) {
            comments[index].replies.append(reply)
            comments[index].replyText = ""
            comments[index].isReplying = false
            post.commentCount += 1
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            Avatar(urlString: session.commentAuthor?.avatarURLString, size: .small)

            TextInput(
                placeholder: "Add a comment...",
                text: $newCommentText
            )

            Button {
                sendComment()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.primaryBlue)
            }
            .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.phBackground)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func sendComment() {
        let text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let author = session.commentAuthor else { return }
        let entry = LocalCommentStore.shared.saveTopLevelComment(
            postId: post.id,
            author: author,
            content: text
        )

        let newComment = PostDetailComment(
            id: entry.id,
            comment: entry.toCommentCardData(),
            replies: []
        )

        withAnimation(.easeInOut(duration: 0.2)) {
            comments.insert(newComment, at: 0)
            post.commentCount += 1
            newCommentText = ""
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

// MARK: - Mock Data

private enum PostDetailMockData {
    static var previewPost: PostItem {
        GardenHomeMockData.posts.first(where: { $0.id == "nl1" })?.detailItem
            ?? PostItem(
                id: "nl1",
                user: GardenCommunityProfiles.postCardUser(id: "u1"),
                imageAssetName: MockPlantImages.nlMonsteraUnfurlMacro,
                content: "Day 5 of unfurling — the new leaf is still rolled but the first fenestration slits are opening.",
                createdAt: Date().addingTimeInterval(-1_800),
                likeCount: 34,
                commentCount: 5,
                isLiked: false,
                isSaved: false,
                plantTags: [PostPlantTag(id: "monstera", name: "Monstera")]
            )
    }
}

#Preview {
    NavigationStack {
        PostDetailView(post: PostDetailMockData.previewPost)
    }
}
