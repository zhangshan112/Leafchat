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
}
