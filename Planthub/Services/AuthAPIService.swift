import Foundation
import SwiftUI

struct AuthAPIService: Sendable {
    private let client: APIClient
    private let tokenStore: AuthTokenStore

    init(
        client: APIClient = APIClient(),
        tokenStore: AuthTokenStore = .shared
    ) {
        self.client = client
        self.tokenStore = tokenStore
    }

    func register(email: String, password: String, username: String) async throws -> AuthUser {
        let request = AuthRegisterRequest(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            username: username.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let response: AuthResponse = try await client.request(.authRegister(request))

        tokenStore.save(response.data.token)
        await persistSession(user: response.data.user)
        await syncEntitlementsAfterAuth()
        return response.data.user
    }

    func login(email: String, password: String) async throws -> AuthUser {
        let request = AuthLoginRequest(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
        let response: AuthResponse = try await client.request(.authLogin(request))

        tokenStore.save(response.data.token)
        await persistSession(user: response.data.user)
        await syncEntitlementsAfterAuth()
        return response.data.user
    }

    func loginWithApple(identityToken: String, email: String?, fullName: String?) async throws -> AuthUser {
        let request = AuthAppleRequest(
            identityToken: identityToken,
            email: email,
            fullName: fullName
        )
        let response: AuthResponse = try await client.request(.authApple(request))

        tokenStore.save(response.data.token)
        await persistSession(user: response.data.user)
        await syncEntitlementsAfterAuth()
        return response.data.user
    }

    func currentUser() async throws -> AuthUser {
        guard let token = tokenStore.token else {
            throw NetworkError.httpError(statusCode: 401, message: "Unauthorized")
        }

        let response: CurrentUserResponse = try await client.request(.authMe, bearerToken: token)
        await persistSession(user: response.data.user)
        return response.data.user
    }

    func updateProfile(_ request: ProfileUpdateRequest) async throws -> AuthUser {
        guard let token = tokenStore.token else {
            throw NetworkError.httpError(statusCode: 401, message: "Unauthorized")
        }

        let response: CurrentUserResponse = try await client.request(
            .authUpdateProfile(request),
            bearerToken: token
        )
        await persistSession(user: response.data.user)
        return response.data.user
    }

    func logout() async {
        await clearSession()
    }

    func deleteAccount() async throws {
        guard let token = tokenStore.token else {
            throw NetworkError.httpError(statusCode: 401, message: "Unauthorized")
        }

        try await client.requestVoid(.authDeleteAccount, bearerToken: token)
        tokenStore.clear()
        await clearSession()
    }

    @MainActor
    private func persistSession(user: AuthUser) {
        UserSessionStore.shared.apply(user)
    }

    @MainActor
    private func syncEntitlementsAfterAuth() async {
        await EntitlementAPIService.shared.hydrateFromServer()
    }

    @MainActor
    private func clearSession() {
        UserSessionStore.shared.clear()
    }
}

private struct AuthAPIServiceKey: EnvironmentKey {
    static let defaultValue = AuthAPIService()
}

extension EnvironmentValues {
    var authAPIService: AuthAPIService {
        get { self[AuthAPIServiceKey.self] }
        set { self[AuthAPIServiceKey.self] = newValue }
    }
}
