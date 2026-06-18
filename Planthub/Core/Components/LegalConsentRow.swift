import SwiftUI

/// Checkbox row for agreeing to Terms of Service and Privacy Policy before auth actions.
struct LegalConsentRow: View {

    @Binding var isAccepted: Bool

    @State private var presentedDocument: LegalDocument?

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
        .sheet(item: $presentedDocument) { document in
            NavigationStack {
                LegalPlaceholderView(title: document.title, url: document.url)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                presentedDocument = nil
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.primaryBlue)
                        }
                    }
            }
        }
    }

    private var consentText: some View {
        Text(consentAttributedString)
            .font(.system(size: 13))
            .foregroundStyle(Color.textSecondary)
            .tint(Color.primaryBlue)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.openURL, OpenURLAction { url in
                if url == LegalLinks.termsOfService {
                    presentedDocument = .termsOfService
                    return .handled
                }
                if url == LegalLinks.privacyPolicy {
                    presentedDocument = .privacyPolicy
                    return .handled
                }
                return .systemAction
            })
    }

    private var consentAttributedString: AttributedString {
        var text = AttributedString("I agree to the ")
        var terms = AttributedString("Terms of Service")
        terms.link = LegalLinks.termsOfService
        text.append(terms)
        text.append(AttributedString(" and "))
        var privacy = AttributedString("Privacy Policy")
        privacy.link = LegalLinks.privacyPolicy
        text.append(privacy)
        text.append(AttributedString("."))
        return text
    }
}

private enum LegalDocument: Identifiable {
    case termsOfService
    case privacyPolicy

    var id: Self { self }

    var title: String {
        switch self {
        case .termsOfService: "Terms of Service"
        case .privacyPolicy: "Privacy Policy"
        }
    }

    var url: URL {
        switch self {
        case .termsOfService: LegalLinks.termsOfService
        case .privacyPolicy: LegalLinks.privacyPolicy
        }
    }
}
