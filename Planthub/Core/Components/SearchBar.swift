import SwiftUI

// MARK: - SearchBar

/// Unified search input. Height 44, phSurface background, radius 12.
/// Leading magnifyingglass icon, trailing clear button when text is non-empty.
/// Exposes `onSearch` (keyboard Search key) and `onCancel` callbacks.
struct SearchBar: View {

    @Binding var text: String
    var placeholder: String = "Search plants, users..."
    var isLoading: Bool = false
    var autoFocus: Bool = false

    /// Triggered when the user taps the keyboard Search / Return key.
    var onSearch: (() -> Void)? = nil
    /// Triggered when the user taps Cancel.
    var onCancel: (() -> Void)? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            searchField
            if isFocused {
                cancelButton
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .onAppear {
            if autoFocus {
                DispatchQueue.main.async {
                    isFocused = true
                }
            }
        }
    }

    // MARK: Private

    private var searchField: some View {
        HStack(spacing: 8) {
            // Leading icon
            if isLoading {
                ProgressView()
                    .tint(Color.textSecondary)
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.textSecondary)
            }

            // Text field
            TextField(placeholder, text: $text)
                .focused($isFocused)
                .submitLabel(.search)
                .onSubmit { onSearch?() }

            // Trailing clear button
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textSecondary)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Color.phSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.15), value: text.isEmpty)
    }

    private var cancelButton: some View {
        Button("Cancel") {
            text = ""
            isFocused = false
            onCancel?()
        }
        .font(.system(size: 16))
        .foregroundStyle(Color.primaryBlue)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var query = ""
    @Previewable @State var plantQuery = "Monst"

    VStack(spacing: 16) {
        SearchBar(text: $query)

        SearchBar(
            text: $plantQuery,
            placeholder: "Search plants",
            onSearch: { print("search: \(plantQuery)") }
        )

        SearchBar(text: .constant(""), isLoading: true)
    }
    .padding(.horizontal, 16)
}
