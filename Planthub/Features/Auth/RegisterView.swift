import SwiftUI

struct RegisterView: View {

    var onSuccess: () -> Void = {}
    var onLogIn: () -> Void = {}

    @Environment(\.authAPIService) private var authAPIService

    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var registerError: String? = nil
    @State private var hasAcceptedTerms = false
    @State private var showTermsRequiredAlert = false

    // Dirty flags: show errors only after the user has interacted with each field
    @State private var touchedUsername = false
    @State private var touchedEmail = false
    @State private var touchedPassword = false
    @State private var touchedConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                    .padding(.bottom, 32)

                formSection
                    .padding(.horizontal, 24)

                Spacer().frame(height: 24)

                logInLink
                    .padding(.bottom, 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .authScreenStyle()
        .termsRequiredAlert(isPresented: $showTermsRequiredAlert)
        .authLoadingOverlay(isPresented: isLoading, message: "Creating your account...")
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.tagBackground)
                    .frame(width: 80, height: 80)
                Circle()
                    .fill(Color.primaryBlue.opacity(0.06))
                    .frame(width: 58, height: 58)
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.primaryBlue)
            }

            VStack(spacing: 6) {
                Text("Create Account")
                    .font(.pageTitle)
                    .foregroundStyle(Color.textPrimary)
                Text("Join the plant lovers community.")
                    .font(.captionText)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.top, 40)
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: 20) {
            AuthTextInput(
                label: "Username",
                placeholder: "Enter your username",
                text: $username,
                leadingIcon: "person",
                errorMessage: touchedUsername ? usernameError : nil,
                textInputAutocapitalization: .never
            )
            .onChange(of: username) { _, _ in touchedUsername = true }

            AuthTextInput(
                label: "Email",
                placeholder: "Enter your email",
                text: $email,
                leadingIcon: "envelope",
                errorMessage: touchedEmail ? emailError : nil,
                keyboardType: .emailAddress,
                textInputAutocapitalization: .never
            )
            .onChange(of: email) { _, _ in touchedEmail = true }

            AuthTextInput(
                label: "Password",
                placeholder: "Enter password",
                text: $password,
                leadingIcon: "lock",
                isSecure: true,
                errorMessage: touchedPassword ? passwordError : nil
            )
            .onChange(of: password) { _, _ in touchedPassword = true }

            AuthTextInput(
                label: "Confirm Password",
                placeholder: "Confirm your password",
                text: $confirmPassword,
                leadingIcon: "lock",
                isSecure: true,
                errorMessage: touchedConfirm ? confirmError : nil
            )
            .onChange(of: confirmPassword) { _, _ in touchedConfirm = true }

            if let registerError {
                Text(registerError)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }

            LegalConsentRow(isAccepted: $hasAcceptedTerms)

            PrimaryButton(
                title: "Create Account",
                isDisabled: isLoading || !isFormValid
            ) {
                guard requireTermsAcceptance() else { return }
                handleRegister()
            }
        }
        .disabled(isLoading)
    }

    // MARK: - Log in link

    private var logInLink: some View {
        HStack(spacing: 4) {
            Text("Already have an account?")
                .font(.captionText)
                .foregroundStyle(Color.textSecondary)
            Button("Log In") {
                onLogIn()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.primaryBlue)
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
    }

    // MARK: - Validation

    private var usernameError: String? {
        guard !username.isEmpty else { return nil }
        if username.count < 3 { return "Username must be at least 3 characters." }
        if username.count > 20 { return "Username must be 20 characters or fewer." }
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "_"))
        if username.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            return "Only letters, numbers, and underscores allowed."
        }
        return nil
    }

    private var emailError: String? {
        guard !email.isEmpty else { return nil }
        let atCount = email.filter { $0 == "@" }.count
        guard atCount == 1,
              let atIndex = email.firstIndex(of: "@"),
              email.distance(from: atIndex, to: email.endIndex) > 2,
              email.contains(".")
        else {
            return "Invalid email address."
        }
        return nil
    }

    private var passwordError: String? {
        guard !password.isEmpty else { return nil }
        return password.count < 6
            ? "Password must be at least 6 characters."
            : nil
    }

    private var confirmError: String? {
        guard !confirmPassword.isEmpty else { return nil }
        return confirmPassword != password ? "Passwords do not match." : nil
    }

    private var isFormValid: Bool {
        usernameError == nil && !username.isEmpty &&
        emailError == nil && !email.isEmpty &&
        passwordError == nil && !password.isEmpty &&
        confirmError == nil && !confirmPassword.isEmpty
    }

    // MARK: - Register logic

    private func requireTermsAcceptance() -> Bool {
        guard hasAcceptedTerms else {
            showTermsRequiredAlert = true
            return false
        }
        return true
    }

    private func handleRegister() {
        guard isFormValid else { return }
        // Mark all fields as touched to surface any remaining errors
        touchedUsername = true
        touchedEmail = true
        touchedPassword = true
        touchedConfirm = true
        guard isFormValid else { return }

        isLoading = true
        registerError = nil

        Task {
            do {
                _ = try await authAPIService.register(
                    email: email,
                    password: password,
                    username: username
                )
                await MainActor.run {
                    isLoading = false
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    registerError = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    RegisterView()
}
