import SwiftUI
import UIKit

// MARK: - Avatar Size

enum AvatarSize {
    case small   // 32×32 — comments, notifications, chat rows
    case medium  // 48×48 — post cards, user cards
    case large   // 80×80 — profile headers

    var dimension: CGFloat {
        switch self {
        case .small:  return 32
        case .medium: return 48
        case .large:  return 80
        }
    }
}

// MARK: - Avatar

/// Circular user avatar. Supports `data:` URLs stored in the database, local files, and remote URLs.
struct Avatar: View {

    private let urlString: String?
    var size: AvatarSize = .medium
    var onTap: (() -> Void)? = nil

    init(urlString: String?, size: AvatarSize = .medium, onTap: (() -> Void)? = nil) {
        self.urlString = urlString?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.size = size
        self.onTap = onTap
    }

    init(url: URL?, size: AvatarSize = .medium, onTap: (() -> Void)? = nil) {
        self.init(urlString: url?.absoluteString, size: size, onTap: onTap)
    }

    var body: some View {
        Group {
            if let onTap {
                content
                    .frame(width: size.dimension, height: size.dimension)
                    .clipShape(Circle())
                    .contentShape(Circle())
                    .onTapGesture(perform: onTap)
            } else {
                content
                    .frame(width: size.dimension, height: size.dimension)
                    .clipShape(Circle())
            }
        }
    }

    // MARK: Private

    @ViewBuilder
    private var content: some View {
        if let urlString, let localImage = AvatarImageLoader.image(from: urlString) {
            Image(uiImage: localImage)
                .resizable()
                .scaledToFill()
        } else if let urlString, AvatarImageLoader.isRemoteURL(urlString), let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholder
                        .overlay(
                            Circle()
                                .fill(Color.phSurface)
                                .shimmering()
                        )
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.phSurface
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .padding(4)
                .foregroundStyle(Color.textSecondary)
        }
    }
}

// MARK: - Shimmer modifier

private struct ShimmeringModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.phSurface.opacity(0),
                        Color.phSurface.opacity(0.6),
                        Color.phSurface.opacity(0)
                    ]),
                    startPoint: .init(x: phase - 0.3, y: 0.5),
                    endPoint:   .init(x: phase + 0.3, y: 0.5)
                )
                .clipShape(Circle())
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.4)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1.3
                }
            }
    }
}

private extension View {
    func shimmering() -> some View {
        modifier(ShimmeringModifier())
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
