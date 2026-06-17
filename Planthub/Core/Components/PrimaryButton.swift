import SwiftUI

// MARK: - PrimaryButton

/// Full-width primary action button.
/// Supports default, loading, and disabled states.
struct PrimaryButton: View {

    enum Style {
        case filled
        case light
        case outlined
    }

    let title: String
    var style: Style = .filled
    var isCompact: Bool = false
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: handleTap) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(progressTint)
                } else {
                    Text(title)
                        .font(titleFont)
                        .foregroundStyle(titleColor)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .background { buttonBackground }
            .clipShape(RoundedRectangle(cornerRadius: isCompact ? 10 : 12))
            .shadow(
                color: style == .filled && !(isDisabled || isLoading) && !isCompact
                    ? Color(hex: "#7C3AED").opacity(0.30)
                    : .clear,
                radius: 8, x: 0, y: 4
            )
            .overlay(outlineBorder)
        }
        .buttonStyle(.plain)
        .tint(.white)
        .disabled(isLoading || isDisabled)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
    }

    // MARK: Private

    private var buttonHeight: CGFloat { isCompact ? 34 : 48 }

    private var titleFont: Font {
        .system(size: isCompact ? 14 : 16, weight: .semibold)
    }

    private var buttonBackground: some View {
        Group {
            switch style {
            case .filled:
                if isDisabled || isLoading {
                    LinearGradient(
                        colors: [Color(hex: "#8B5CF6").opacity(0.4), Color(hex: "#7C3AED").opacity(0.4)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                } else {
                    LinearGradient(
                        colors: [Color(hex: "#8B5CF6"), Color(hex: "#7C3AED")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
            case .light:
                LinearGradient(
                    colors: [Color.white.opacity(isDisabled || isLoading ? 0.4 : 1)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case .outlined:
                LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom)
            }
        }
    }

    @ViewBuilder
    private var outlineBorder: some View {
        if style == .outlined {
            RoundedRectangle(cornerRadius: isCompact ? 10 : 12)
                .stroke(outlineBorderColor, lineWidth: 1)
        }
    }

    private var outlineBorderColor: Color {
        if isDisabled || isLoading {
            return Color.white.opacity(0.4)
        }
        return Color.white
    }

    private var titleColor: Color {
        switch style {
        case .filled:
            return .white
        case .light:
            if isDisabled || isLoading {
                return Color.accentBlack.opacity(0.4)
            }
            return Color.accentBlack
        case .outlined:
            if isDisabled || isLoading {
                return Color.white.opacity(0.4)
            }
            return Color.white
        }
    }

    private var progressTint: Color {
        switch style {
        case .filled:
            return .white
        case .light:
            return Color.accentBlack
        case .outlined:
            return .white
        }
    }

    private func handleTap() {
        guard !isLoading, !isDisabled else { return }
        action()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "Continue") {}

        PrimaryButton(title: "Publish", isLoading: true) {}

        PrimaryButton(title: "Save", isDisabled: true) {}
    }
    .padding(.horizontal, 16)
}
