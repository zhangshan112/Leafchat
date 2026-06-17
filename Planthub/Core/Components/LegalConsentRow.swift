import SwiftUI

/// Checkbox row for agreeing to Terms of Service and Privacy Policy before auth actions.
struct LegalConsentRow: View {

    @Binding var isAccepted: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                isAccepted.toggle()
            } label: {
                Image(systemName: isAccepted ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundStyle(isAccepted ? Color.primaryBlue : Color.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Agree to Terms of Service and Privacy Policy")
            .accessibilityValue(isAccepted ? "Checked" : "Unchecked")

            consentText
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var consentText: some View {
        Text("I agree to the [Terms of Service](\(LegalLinks.termsOfService.absoluteString)) and [Privacy Policy](\(LegalLinks.privacyPolicy.absoluteString)).")
            .font(.system(size: 13))
            .foregroundStyle(Color.textSecondary)
            .tint(Color.primaryBlue)
            .fixedSize(horizontal: false, vertical: true)
    }
}
