import SwiftUI

// MARK: - TextInput

/// Single-line text input with placeholder, optional secure entry, focused
/// highlight, disabled state, and inline error message.
struct TextInput: View {

    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var isDisabled: Bool = false
    var errorMessage: String? = nil
    var onSubmit: (() -> Void)? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            inputField
                .frame(height: 48)
                .padding(.horizontal, 16)
                .background(Color.phSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: 1)
                )
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.5 : 1)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
                .animation(.easeInOut(duration: 0.15), value: errorMessage)

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.red)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
    }

    // MARK: Private

    @ViewBuilder
    private var inputField: some View {
        if isSecure {
            SecureField(placeholder, text: $text)
                .focused($isFocused)
        } else {
            TextField(placeholder, text: $text)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit {
                    onSubmit?()
                }
        }
    }

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
    @Previewable @State var email = ""
    @Previewable @State var password = ""
    @Previewable @State var username = "taken_name"

    VStack(spacing: 16) {
        TextInput(placeholder: "Email", text: $email)

        TextInput(placeholder: "Password", text: $password, isSecure: true)

        TextInput(
            placeholder: "Username",
            text: $username,
            errorMessage: "Username is already taken."
        )

        TextInput(placeholder: "Disabled field", text: .constant(""), isDisabled: true)
    }
    .padding(.horizontal, 16)
}
