import AuthenticationServices
import CryptoKit
import SwiftUI
import UIKit

struct LoginView: View {

    var onLoginSuccess: () -> Void = {}
    var onSignUp: () -> Void = {}

    @Environment(\.authAPIService) private var authAPIService

    @State private var showEmailLogin = false
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var isAppleLoading = false
    @State private var loginError: String? = nil
    @State private var hasAcceptedTerms = false
    @State private var showTermsRequiredAlert = false
    @State private var appleSignInCoordinator = AppleSignInCoordinator()

    private var isAuthLoading: Bool {
        isLoading || isAppleLoading
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer()

                    logoSection
                        .padding(.bottom, 48)

                    Spacer()

                    authButtons
                        .padding(.horizontal, 24)

                    Spacer().frame(height: 32)

                    signUpLink

                    Spacer().frame(height: 48)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
        }
        .authScreenStyle()
        .termsRequiredAlert(isPresented: $showTermsRequiredAlert)
        .authLoadingOverlay(isPresented: isAuthLoading, message: "Signing you in...")
    }

    // MARK: - Logo

    private var logoSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.tagBackground)
                    .frame(width: 100, height: 100)
                Circle()
                    .fill(Color.primaryBlue.opacity(0.06))
                    .frame(width: 72, height: 72)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.primaryBlue)
            }

            VStack(spacing: 6) {
                Text(AppBranding.name)
                    .font(.pageTitle)
                    .foregroundStyle(Color.textPrimary)

                Text("The social network for plant lovers.")
                    .font(.captionText)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    // MARK: - Auth buttons

    private var authButtons: some View {
        VStack(spacing: 12) {
            LegalConsentRow(isAccepted: $hasAcceptedTerms)

            appleButton
            emailButton

            if showEmailLogin {
                emailLoginSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else if let loginError {
                Text(loginError)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        }
        .animation(.spring(response: 0.35), value: showEmailLogin)
    }

    private var appleButton: some View {
        AuthOutlineButton(
            title: "Continue with Apple",
            systemImage: "apple.logo"
        ) {
            guard requireTermsAcceptance() else { return }
            handleAppleLogin()
        }
        .disabled(isAuthLoading)
    }

    private var emailButton: some View {
        AuthOutlineButton(
            title: showEmailLogin ? "Hide Email Login" : "Continue with Email",
            systemImage: "envelope"
        ) {
            if !showEmailLogin {
                guard requireTermsAcceptance() else { return }
            }

            withAnimation(.spring(response: 0.35)) {
                showEmailLogin.toggle()
                if !showEmailLogin {
                    email = ""
                    password = ""
                    loginError = nil
                }
            }
        }
        .disabled(isAuthLoading)
    }

    // MARK: - Inline email login

    @ViewBuilder
    private var emailLoginSection: some View {
        VStack(spacing: 12) {
            AuthTextInput(
                label: "Email",
                placeholder: "Enter your email",
                text: $email,
                leadingIcon: "envelope",
                keyboardType: .emailAddress,
                textInputAutocapitalization: .never
            )
            AuthTextInput(
                label: "Password",
                placeholder: "Enter password",
                text: $password,
                leadingIcon: "lock",
                isSecure: true
            )

            if let loginError {
                Text(loginError)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }

            PrimaryButton(
                title: "Log In",
                isDisabled: isAuthLoading
                    || email.trimmingCharacters(in: .whitespaces).isEmpty
                    || password.isEmpty
            ) {
                guard requireTermsAcceptance() else { return }
                handleEmailLogin()
            }
        }
        .disabled(isAuthLoading)
    }

    // MARK: - Sign up link

    private var signUpLink: some View {
        HStack(spacing: 4) {
            Text("Don't have an account?")
                .font(.captionText)
                .foregroundStyle(Color.textSecondary)
            Button("Sign Up") {
                onSignUp()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.primaryBlue)
            .buttonStyle(.plain)
            .disabled(isAuthLoading)
        }
    }

    // MARK: - Login logic

    private func requireTermsAcceptance() -> Bool {
        guard hasAcceptedTerms else {
            showTermsRequiredAlert = true
            return false
        }
        return true
    }

    private func handleEmailLogin() {
        guard !email.isEmpty, !password.isEmpty else { return }
        isLoading = true
        loginError = nil

        Task {
            do {
                _ = try await authAPIService.login(email: email, password: password)
                await MainActor.run {
                    isLoading = false
                    onLoginSuccess()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    loginError = error.localizedDescription
                }
            }
        }
    }

    private func handleAppleLogin() {
        guard !isAppleLoading, !isLoading else { return }
        loginError = nil
        isAppleLoading = true

        Task {
            do {
                let applePayload = try await appleSignInCoordinator.signIn()
                _ = try await authAPIService.loginWithApple(
                    identityToken: applePayload.identityToken,
                    email: applePayload.email,
                    fullName: applePayload.fullName
                )

                await MainActor.run {
                    isAppleLoading = false
                    onLoginSuccess()
                }
            } catch let error as AppleSignInCoordinatorError {
                await MainActor.run {
                    isAppleLoading = false
                    if error != .userCanceled {
                        loginError = error.localizedDescription
                    }
                }
            } catch {
                await MainActor.run {
                    isAppleLoading = false
                    loginError = error.localizedDescription
                }
            }
        }
    }
}

private struct AppleSignInPayload {
    let identityToken: String
    let email: String?
    let fullName: String?
}

private enum AppleSignInCoordinatorError: LocalizedError, Equatable {
    case requestInProgress
    case presentationContextUnavailable
    case invalidCredentialType
    case missingIdentityToken
    case invalidIdentityTokenEncoding
    case userCanceled

    var errorDescription: String? {
        switch self {
        case .requestInProgress:
            "Apple sign-in is already in progress."
        case .presentationContextUnavailable:
            "Unable to open Apple sign-in right now. Please try again."
        case .invalidCredentialType:
            "Unable to read Apple sign-in credentials."
        case .missingIdentityToken:
            "Apple sign-in response is missing identity token."
        case .invalidIdentityTokenEncoding:
            "Unable to decode Apple identity token."
        case .userCanceled:
            "Apple sign-in canceled."
        }
    }
}

@MainActor
private final class AppleSignInCoordinator: NSObject {
    private var continuation: CheckedContinuation<AppleSignInPayload, Error>?
    private var authorizationController: ASAuthorizationController?
    private weak var presentationAnchorWindow: UIWindow?

    func signIn() async throws -> AppleSignInPayload {
        guard continuation == nil else {
            throw AppleSignInCoordinatorError.requestInProgress
        }

        guard let window = UIApplication.shared.activeKeyWindow else {
            throw AppleSignInCoordinatorError.presentationContextUnavailable
        }

        presentationAnchorWindow = window

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(Self.randomNonce())

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            authorizationController = controller
            controller.performRequests()
        }
    }

    private func finish(with result: Result<AppleSignInPayload, Error>) {
        guard let continuation else { return }

        self.continuation = nil
        authorizationController = nil
        presentationAnchorWindow = nil
        continuation.resume(with: result)
    }

    private static func randomNonce(length: Int = 32) -> String {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        return String((0 ..< length).compactMap { _ in
            characters.randomElement()
        })
    }

    private static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(with: .failure(AppleSignInCoordinatorError.invalidCredentialType))
            return
        }

        guard let identityTokenData = credential.identityToken else {
            finish(with: .failure(AppleSignInCoordinatorError.missingIdentityToken))
            return
        }

        guard let identityToken = String(data: identityTokenData, encoding: .utf8),
              !identityToken.isEmpty
        else {
            finish(with: .failure(AppleSignInCoordinatorError.invalidIdentityTokenEncoding))
            return
        }

        let email = credential.email?.trimmedToNil
        let fullName = credential.fullName?.formattedName
        let payload = AppleSignInPayload(identityToken: identityToken, email: email, fullName: fullName)
        finish(with: .success(payload))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if (error as? ASAuthorizationError)?.code == .canceled {
            finish(with: .failure(AppleSignInCoordinatorError.userCanceled))
            return
        }

        finish(with: .failure(error))
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentationAnchorWindow ?? ASPresentationAnchor()
    }
}

private extension PersonNameComponents {
    var formattedName: String? {
        let formatter = PersonNameComponentsFormatter()
        let value = formatter.string(from: self).trimmingCharacters(in: .whitespacesAndNewlines)

        return value.isEmpty ? nil : value
    }
}

private extension String {
    var trimmedToNil: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

private extension UIApplication {
    var activeKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}

#Preview {
    LoginView()
}
