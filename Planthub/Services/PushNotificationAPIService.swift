import Foundation
import SwiftUI

struct PushNotificationAPIService: Sendable {
    private let client: APIClient
    private let tokenStore: AuthTokenStore

    init(
        client: APIClient = APIClient(),
        tokenStore: AuthTokenStore = .shared
    ) {
        self.client = client
        self.tokenStore = tokenStore
    }

    /// Registers or refreshes the device token on the backend.
    /// The endpoint is wired now; the server can implement it when push delivery is ready.
    func registerDeviceToken(
        _ token: String,
        preferences: PushNotificationPreferences
    ) async throws {
        guard let bearerToken = tokenStore.token else { return }

        let request = RegisterPushTokenRequest(token: token, preferences: preferences)
        try await client.requestVoid(.registerPushToken(request), bearerToken: bearerToken)
    }
}

private struct PushNotificationAPIServiceKey: EnvironmentKey {
    static let defaultValue = PushNotificationAPIService()
}

extension EnvironmentValues {
    var pushNotificationAPIService: PushNotificationAPIService {
        get { self[PushNotificationAPIServiceKey.self] }
        set { self[PushNotificationAPIServiceKey.self] = newValue }
    }
}
