import SwiftUI

// MARK: - Auth state

enum AuthState {
    case bootstrapping
    case onboarding
    case login
    case register
    case completeProfile
    case main
}

// MARK: - RootView

/// App entry point. Routes between auth flow and main tab bar based on AuthState.
///
/// Flow for first-time users:  Launch → Onboarding → Login / Register → Complete Profile → Main
/// Flow for returning users:   Launch → Login → Main  (onboarding already seen)
/// Flow on session restore:    Launch → Main  (skip everything)
struct RootView: View {

    @Environment(\.authAPIService) private var authAPIService

    @State private var authState: AuthState = .bootstrapping
    @State private var bootstrapTargetState: AuthState?
    @State private var launchAnimationFinished = false

    private static let onboardingSeenKey = "hasSeenOnboarding"

    var body: some View {
        ZStack {
            switch authState {
            case .bootstrapping:
                LaunchAnimationView {
                    launchAnimationFinished = true
                    continueAfterBootstrapIfReady()
                }
                .transition(pageTransition)

            case .onboarding:
                OnboardingView(
                    onComplete: {
                        markOnboardingSeen()
                        transition(to: .login)
                    },
                    onSignUp: {
                        markOnboardingSeen()
                        transition(to: .register)
                    }
                )
                .transition(pageTransition)

            case .login:
                LoginView(
                    onLoginSuccess: { transition(to: .main) },
                    onSignUp:       { transition(to: .register) }
                )
                .transition(pageTransition)

            case .register:
                RegisterView(
                    onSuccess: { transition(to: .completeProfile) },
                    onLogIn:   { transition(to: .login) }
                )
                .transition(pageTransition)

            case .completeProfile:
                CompleteProfileView(
                    onComplete: { transition(to: .main) }
                )
                .transition(pageTransition)

            case .main:
                MainTabView(
                    onLogout: {
                        Task {
                            await authAPIService.logout()
                            transition(to: .login)
                        }
                    },
                    onAccountDeleted: {
                        transition(to: .login)
                    }
                )
                .transition(pageTransition)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authState)
        .task {
            guard authState == .bootstrapping else { return }

            let result = await UserSessionStore.shared.restoreSession()
            if result == .restored {
                bootstrapTargetState = .main
            } else {
                let hasSeenOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingSeenKey)
                bootstrapTargetState = hasSeenOnboarding ? .login : .onboarding
            }
            continueAfterBootstrapIfReady()
        }
        .task(id: authState) {
            guard authState == .main else { return }
            IAPManager.shared.start()
            await EntitlementAPIService.shared.hydrateFromServer()
        }
    }

    // MARK: Private

    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal:   .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func continueAfterBootstrapIfReady() {
        guard authState == .bootstrapping,
              launchAnimationFinished,
              let targetState = bootstrapTargetState else {
            return
        }
        transition(to: targetState)
    }

    private func transition(to state: AuthState) {
        if state == .main {
            AppTabRouter.shared.resetToHome()
        } else if authState == .main {
            AppTabRouter.shared.resetToHome()
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            authState = state
        }
    }

    private func markOnboardingSeen() {
        UserDefaults.standard.set(true, forKey: Self.onboardingSeenKey)
    }
}

#Preview {
    RootView()
}
