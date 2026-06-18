import SwiftUI

extension View {
    /// Light auth screen background — matches the onboarding visual style.
    func authScreenStyle() -> some View {
        background(Color.phBackground.ignoresSafeArea())
    }

    /// Alert shown when the user tries to continue without accepting legal terms.
    func termsRequiredAlert(isPresented: Binding<Bool>) -> some View {
        alert("Agreement Required", isPresented: isPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please agree to the Terms of Service and Privacy Policy before continuing.")
        }
    }

    /// Full-screen loading overlay for auth flows — blocks interaction while a request is in flight.
    func authLoadingOverlay(isPresented: Bool, message: String) -> some View {
        overlay {
            if isPresented {
                ZStack {
                    Color.black
                        .opacity(0.25)
                        .ignoresSafeArea()

                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.15)
                            .tint(Color.primaryBlue)

                        Text(message)
                            .font(.captionText)
                            .foregroundStyle(Color.textPrimary)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 22)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.phBackground)
                            .shadow(color: Color.black.opacity(0.12), radius: 16, y: 4)
                    )
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPresented)
    }
}
