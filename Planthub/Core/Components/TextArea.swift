import SwiftUI

// MARK: - TextArea

/// Multi-line text input that expands vertically with content.
/// Minimum height 120 pt. Supports placeholder overlay, optional character
/// limit counter, focused border highlight, and disabled state.
struct TextArea: View {

    let placeholder: String
    @Binding var text: String
    var maxLength: Int? = nil
    var isDisabled: Bool = false
    var errorMessage: String? = nil

    @FocusState private var isFocused: Bool

    private let minHeight: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                // Placeholder — shown when text is empty and not focused
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.textSecondary)
                        .padding(.top, 12)
                        .padding(.horizontal, 16)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $text)
                    .focused($isFocused)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: minHeight)
                    .onChange(of: text) { _, newValue in
                        if let max = maxLength, newValue.count > max {
                            text = String(newValue.prefix(max))
                        }
                    }
            }
            .background(Color.phSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.5 : 1)
            .animation(.easeInOut(duration: 0.15), value: isFocused)

            // Footer row: error message (leading) + char count (trailing)
            HStack {
                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.red)
                }
                Spacer()
                if let max = maxLength {
                    Text("\(text.count) / \(max)")
                        .font(.system(size: 12))
                        .foregroundStyle(text.count >= max ? Color.red : Color.textSecondary)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: errorMessage)
        }
    }

    // MARK: Private

    private var borderColor: Color {
        if let errorMessage, !errorMessage.isEmpty {
            return Color.red
        }
        if isFocused {
            return Color.primaryBlue
        }
        return Color.phBorder
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var post = ""
    @Previewable @State var bio = "Plant collector"

    VStack(spacing: 20) {
        TextArea(
            placeholder: "What's growing today?",
            text: $post,
            maxLength: 1000
        )

        TextArea(
            placeholder: "Tell plant lovers about yourself.",
            text: $bio,
            maxLength: 150
        )
    }
    .padding(.horizontal, 16)
}
