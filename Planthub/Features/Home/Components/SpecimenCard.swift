import SwiftUI

// MARK: - SpecimenCard

/// Social-style post card for the community home grid.
struct SpecimenCard: View {

    let post: SpecimenPost
    var onLike: (() -> Void)? = nil
    var onSave: (() -> Void)? = nil
    var onComment: (() -> Void)? = nil
    var onAuthorTap: (() -> Void)? = nil
    var onCardTap: (() -> Void)? = nil

    @State private var likeScale: CGFloat = 1.0
    @State private var saveScale: CGFloat = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            postBody

            footer
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primaryBlue.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color(hex: "#7C3AED").opacity(0.07), radius: 12, x: 0, y: 4)
        .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 1)
    }

    private var postBody: some View {
        Button {
            onCardTap?()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                imageSection

                VStack(alignment: .leading, spacing: 6) {
                    plantNameRow

                    if let scientific = post.scientificName {
                        Text(scientific)
                            .font(.system(size: 11, weight: .regular).italic())
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }

                    statusBadge

                    if !post.caption.isEmpty {
                        Text(post.caption)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(2)
                            .lineSpacing(2)
                            .padding(.top, 1)
                    }

                    if !post.plantTags.isEmpty {
                        tagsRow
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subviews

    private var imageSection: some View {
        Color.clear
            .mediaContainer(aspectRatio: post.stature.imageAspect)
            .overlay { imageContent }
            .clipShape(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .inset(by: 8)
            )
            .padding(8)
            .overlay(alignment: .topTrailing) {
                statusIndicatorDot
                    .padding(14)
            }
    }

    private var statusIndicatorDot: some View {
        Circle()
            .fill(statusForeground)
            .frame(width: 8, height: 8)
            .shadow(color: statusForeground.opacity(0.6), radius: 4)
    }

    @ViewBuilder
    private var imageContent: some View {
        Group {
            if let assetName = post.imageAssetName {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            } else if let localImage = post.localImage {
                Image(uiImage: localImage)
                    .resizable()
                    .scaledToFill()
            } else {
                imagePlaceholder
            }
        }
        .mediaFill()
    }

    private var plantNameRow: some View {
        Text(post.plantName)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Color.textPrimary)
            .lineLimit(1)
    }

    private var tagsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(post.plantTags.prefix(3), id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.primaryBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.tagBackground)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.primaryBlue.opacity(0.15), lineWidth: 0.5)
                        )
                }
            }
        }
        .padding(.top, 1)
    }

    private var imagePlaceholder: some View {
        ZStack {
            Color.surfaceViolet
            Image(systemName: "photo.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color.primaryBlue.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusBadge: some View {
        Text(post.status.label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(statusForeground)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(statusForeground.opacity(0.11))
            .clipShape(Capsule())
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Divider()
                .overlay(Color.phBorder.opacity(0.5))

            HStack(spacing: 0) {
            Group {
                if let onAuthorTap {
                    Button(action: onAuthorTap) {
                        authorRowLabel
                    }
                    .buttonStyle(.borderless)
                } else {
                    authorRowLabel
                }
            }

            Spacer(minLength: 4)

            // Like — rose red
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { likeScale = 1.4 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3)) { likeScale = 1.0 }
                }
                onLike?()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: post.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 12))
                        .foregroundStyle(post.isLiked ? Color.likeRed : Color.textSecondary)
                        .scaleEffect(likeScale)
                    Text("\(post.likeCount)")
                        .font(.system(size: 11, weight: post.isLiked ? .semibold : .regular))
                        .foregroundStyle(post.isLiked ? Color.likeRed : Color.textSecondary)
                }
            }
            .buttonStyle(.plain)

            // Comment — brand violet
            Button { onComment?() } label: {
                HStack(spacing: 3) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 11))
                    Text("\(post.commentCount)")
                        .font(.system(size: 11))
                }
                .foregroundStyle(Color.textSecondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 10)

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { saveScale = 1.45 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(.spring(response: 0.3)) { saveScale = 1.0 }
                }
                onSave?()
            } label: {
                Image(systemName: post.isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 12))
                    .foregroundStyle(post.isSaved ? Color.savedAmber : Color.textSecondary)
                    .scaleEffect(saveScale)
            }
            .buttonStyle(.plain)
            .padding(.leading, 10)
            }
        }
    }

    private var authorRowLabel: some View {
        HStack(spacing: 6) {
            Avatar(urlString: post.author.avatarUrlString, size: .small)

            Text(post.author.username)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
        }
        .padding(.vertical, 10)
        .padding(.trailing, 8)
        .frame(minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    // MARK: - Status colors

    private var statusForeground: Color {
        switch post.status {
        case .thriving:   return Color.primaryBlue
        case .recovering: return Color.savedAmber
        case .sprouting:  return Color.hotCoral
        case .resting:    return Color.textSecondary
        }
    }
}
