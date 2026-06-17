import SwiftUI

// MARK: - FollowButton

/// Two-state follow button used on UserCard and UserProfile.
/// Follow  → solid primaryBlue background, white text.
/// Following → transparent background, primaryBlue border + text.
/// State transitions animate with .easeInOut(duration: 0.2).
struct FollowButton: View {

    var isFollowing: Bool
    var isLoading: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: handleTap) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(isFollowing ? Color.primaryBlue : .white)
                        .scaleEffect(0.85)
                } else {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isFollowing ? Color.primaryBlue : .white)
                }
            }
            .frame(width: 100, height: 34)
            .background(buttonBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primaryBlue, lineWidth: isFollowing ? 1 : 0)
            )
        }
        .disabled(isLoading)
        .animation(.easeInOut(duration: 0.2), value: isFollowing)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }

    // MARK: Private

    private var buttonBackground: Color {
        if isLoading {
            return isFollowing ? Color.phSurface : Color.primaryBlue.opacity(0.6)
        }
        return isFollowing ? Color.clear : Color.primaryBlue
    }

    private func handleTap() {
        guard !isLoading else { return }
        action()
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var following = false

    VStack(spacing: 20) {
        // Toggle demo
        FollowButton(isFollowing: following) {
            following.toggle()
        }

        // Static states
        FollowButton(isFollowing: false) {}
        FollowButton(isFollowing: true) {}
        FollowButton(isFollowing: false, isLoading: true) {}
        FollowButton(isFollowing: true, isLoading: true) {}
    }
    .padding()
}
