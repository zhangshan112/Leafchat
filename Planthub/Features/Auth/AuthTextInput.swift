import SwiftUI

/// Auth screen text field styled for light backgrounds — label, leading icon, optional visibility toggle.
struct AuthTextInput: View {

    let label: String
    let placeholder: String
    @Binding var text: String
    var leadingIcon: String
    var isSecure: Bool = false
    var isDisabled: Bool = false
    var errorMessage: String? = nil
    var keyboardType: UIKeyboardType = .default
    var textInputAutocapitalization: TextInputAutocapitalization = .sentences

    @FocusState private var isFocused: Bool
    @State private var isPasswordVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.textPrimary)

            HStack(spacing: 0) {
                Image(systemName: leadingIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 18, height: 18)
                    .padding(.trailing, 10)

                inputField
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textPrimary)
                    .tint(Color.primaryBlue)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSecure {
                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.textSecondary)
                            .frame(width: 18, height: 18)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, -8)
                }
            }
            .padding(.horizontal, 15)
            .frame(height: 48)
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

    @ViewBuilder
    private var inputField: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
                    .allowsHitTesting(false)
            }

            if isSecure, !isPasswordVisible {
                SecureField("", text: $text)
                    .focused($isFocused)
            } else {
                TextField("", text: $text)
                    .focused($isFocused)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(textInputAutocapitalization)
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
