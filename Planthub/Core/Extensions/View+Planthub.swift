import SwiftUI
import UIKit

extension View {
    /// Standard card container: surface background, radius 20, violet-tinted layered shadow.
    func cardStyle() -> some View {
        self
            .background(Color.phSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color(hex: "#7C3AED").opacity(0.06), radius: 14, x: 0, y: 5)
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    /// Community post card: crisp white background, radius 20, rich social depth shadow.
    func communityCardStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color(hex: "#7C3AED").opacity(0.08), radius: 18, x: 0, y: 6)
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    /// Full-width primary button: violet gradient, white text, radius 12, height 50, glow.
    func primaryButtonStyle() -> some View {
        self
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#8B5CF6"), Color(hex: "#7C3AED")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color(hex: "#7C3AED").opacity(0.35), radius: 10, x: 0, y: 4)
    }

    /// Secondary button: transparent bg, violet text/border, radius 12, height 50.
    func secondaryButtonStyle() -> some View {
        self
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.primaryBlue)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primaryBlue, lineWidth: 1.5)
            )
    }

    /// Standard horizontal page padding (16 pt each side).
    func pagePadding() -> some View {
        self.padding(.horizontal, 16)
    }

    /// Skeleton shimmer animation for rectangular loading placeholders.
    func shimmer() -> some View {
        modifier(PHShimmeringModifier())
    }

    /// Constrains a media view to parent width × target aspect ratio without layout overflow.
    ///
    /// `scaledToFill()` images report their natural pixel dimensions back to the layout engine,
    /// which can overflow even when `.clipped()` is applied — `.clipped()` only clips the
    /// visual rendering, not the layout size.  This modifier uses an overlay-anchor pattern:
    ///
    ///   1. `Color.clear` sets the canonical layout size (full width × aspect ratio).
    ///   2. `self` (the image view) is placed in an `.overlay {}` — overlay content never
    ///      affects the parent's layout bounds no matter how large the image reports itself.
    ///   3. `.clipped()` clips any visual bleed from `scaledToFill()`.
    ///
    /// Use on any image wrapper (cards, carousels, hero images) to prevent overflow.
    func mediaContainer(aspectRatio: CGFloat) -> some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay { self }
            .clipped()
    }

    /// Makes media content fill its container and clips visual overflow.
    /// Use on `Image` content inside a size-constrained container.
    func mediaFill() -> some View {
        self
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .clipped()
    }

    /// Dismisses keyboard when tapping blank areas on screen.
    func dismissKeyboardOnTap() -> some View {
        onTapGesture {
            UIApplication.shared.endEditing()
        }
    }

    /// Full-screen blocking loading overlay for async actions.
    func blockingLoadingOverlay(isPresented: Bool, message: String = "Loading…") -> some View {
        overlay {
            if isPresented {
                ZStack {
                    Color.black.opacity(0.32)
                        .ignoresSafeArea()

                    VStack(spacing: 14) {
                        ProgressView()
                            .tint(Color.primaryBlue)
                            .scaleEffect(1.1)

                        Text(message)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.textPrimary)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 22)
                    .background(Color.phSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.primaryBlue.opacity(0.12), radius: 16, y: 6)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPresented)
    }
}

extension UIApplication {
    func endEditing(_ force: Bool = true) {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .endEditing(force)
    }
}

// MARK: - Shimmer modifier

struct PHShimmeringModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        Color.white.opacity(0.3),
                        .clear
                    ]),
                    startPoint: .init(x: phase - 0.3, y: 0.5),
                    endPoint:   .init(x: phase + 0.3, y: 0.5)
                )
                .allowsHitTesting(false)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }
}
