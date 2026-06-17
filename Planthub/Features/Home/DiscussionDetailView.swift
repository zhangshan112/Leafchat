import SwiftUI

// MARK: - Discussion Models

struct DiscussionItem: Identifiable {
    let id: String
    let author: PostCardUser
    let title: String
    let body: String
    let imageAssetName: String?
    let tags: [PostPlantTag]
    let createdAt: Date
    var isSaved: Bool
}

// MARK: - DiscussionDetailView

struct DiscussionDetailView: View {
    @State private var discussion: DiscussionItem
    @State private var replies: [CommentCardData] = DiscussionDetailMockData.replies
    @State private var replyText = ""
    @State private var isReported = false

    init(discussion: DiscussionItem) {
        _discussion = State(initialValue: discussion)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                authorRow
                titleAndBody

                if let assetName = discussion.imageAssetName {
                    PostImageCarousel(assetNames: [assetName])
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .clipped()
                }

                tagList
                actionBar
                repliesSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            inputBar
        }
        .background(Color.phBackground)
        .navigationTitle("Discussion")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Report Sent", isPresented: $isReported) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thanks for helping keep \(AppBranding.name) safe.")
        }
    }

    // MARK: - Header

    private var authorRow: some View {
        HStack(spacing: 10) {
            Avatar(urlString: discussion.author.avatarUrlString, size: .medium)

            VStack(alignment: .leading, spacing: 2) {
                Text(discussion.author.username)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(discussion.createdAt.phRelative)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()
        }
    }

    private var titleAndBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(discussion.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            Text(discussion.body)
                .font(.system(size: 16))
                .foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var tagList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(discussion.tags) { tag in
                    PlantTagLink(name: tag.name)
                }
            }
        }
    }

    // MARK: - Actions

    private var actionBar: some View {
        HStack(spacing: 18) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    discussion.isSaved.toggle()
                }
            } label: {
                Image(systemName: discussion.isSaved ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(discussion.isSaved ? Color.primaryBlue : Color.textSecondary)
            }
            .buttonStyle(.plain)

            ShareLink(item: "\(discussion.title)\n\n\(discussion.body)") {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(Color.textSecondary)
            }

            Button {
                isReported = true
            } label: {
                Image(systemName: "flag")
                    .foregroundStyle(Color.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .font(.system(size: 18))
        .padding(.vertical, 4)
    }

    // MARK: - Replies

    private var repliesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Replies")
                .font(.sectionTitle)
                .foregroundStyle(Color.textPrimary)

            if replies.isEmpty {
                EmptyStateView(
                    systemImage: "message",
                    title: "No replies yet.",
                    description: "Be the first to join the discussion."
                )
                .frame(minHeight: 220)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(replies.indices, id: \.self) { index in
                        CommentCard(
                            comment: replies[index],
                            onLike: { toggleReplyLike(index) }
                        )
                        if index != replies.indices.last {
                            Divider().padding(.leading, 42)
                        }
                    }
                }
            }
        }
    }

    private func toggleReplyLike(_ index: Int) {
        withAnimation(.spring(response: 0.3)) {
            replies[index].isLiked.toggle()
            replies[index].likeCount += replies[index].isLiked ? 1 : -1
        }
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: 10) {
            Avatar(urlString: nil, size: .small)

            TextInput(
                placeholder: "Add a reply...",
                text: $replyText
            )

            Button {
                sendReply()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(canSendReply ? Color.primaryBlue : Color.textSecondary)
            }
            .disabled(!canSendReply)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.phBackground)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var canSendReply: Bool {
        !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendReply() {
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        replies.insert(
            CommentCardData(
                id: UUID().uuidString,
                userId: "me",
                username: "plantlover99",
                avatarURL: nil,
                content: text,
                createdAt: Date(),
                likeCount: 0,
                isLiked: false
            ),
            at: 0
        )
        replyText = ""
    }
}

// MARK: - Helpers

private extension Date {
    var phRelative: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Mock Data

private enum DiscussionDetailMockData {
    static let discussion = DiscussionItem(
        id: "d1",
        author: PostCardUser(id: "u1", username: "fernqueen", avatarUrlString: nil),
        title: "Why are my fern tips turning brown?",
        body: "I moved my fern closer to the window last week. The soil is still slightly damp, but a few tips are turning brown. Could this be too much light or low humidity?",
        imageAssetName: MockPlantImages.biBostonFernBalcony,
        tags: [
            PostPlantTag(id: "fern", name: "Fern"),
            PostPlantTag(id: "humidity", name: "Humidity")
        ],
        createdAt: Date().addingTimeInterval(-2_400),
        isSaved: false
    )

    static let replies: [CommentCardData] = [
        .init(
            id: "r1",
            userId: "u2",
            username: "roots_n_grows",
            avatarURL: nil,
            content: "Brown tips usually point to dry air. Try moving it away from direct sun and increase humidity.",
            createdAt: Date().addingTimeInterval(-1_800),
            likeCount: 6,
            isLiked: false
        ),
        .init(
            id: "r2",
            userId: "u3",
            username: "plantlover99",
            avatarURL: nil,
            content: "My fern did this when it sat near an air vent. Check for drafts too.",
            createdAt: Date().addingTimeInterval(-1_200),
            likeCount: 3,
            isLiked: true
        )
    ]
}

#Preview {
    NavigationStack {
        DiscussionDetailView(discussion: DiscussionDetailMockData.discussion)
    }
}
