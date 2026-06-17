import SwiftUI

/// Outlined auth action button for light auth screens — border style with system label color.
struct AuthOutlineButton: View {

    let title: String
    var systemImage: String? = nil
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(Color.primaryBlue)
                } else {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundStyle(Color.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.phSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.phBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}
