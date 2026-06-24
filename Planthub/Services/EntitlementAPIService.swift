import Foundation
import SwiftUI

struct EntitlementAPIService: Sendable {
    static let shared = EntitlementAPIService()

    private let client: APIClient
    private let tokenStore: AuthTokenStore

    init(
        client: APIClient = APIClient(),
        tokenStore: AuthTokenStore = .shared
    ) {
        self.client = client
        self.tokenStore = tokenStore
    }

    func fetchEntitlements() async throws -> UserEntitlements {
        guard let token = tokenStore.token else {
            throw NetworkError.httpError(statusCode: 401, message: "Unauthorized")
        }

        let response: EntitlementsResponse = try await client.request(
            .userEntitlements,
            bearerToken: token
        )
        return response.data.entitlements
    }

    func syncEntitlements(_ entitlements: UserEntitlements) async throws -> UserEntitlements {
        guard let token = tokenStore.token else {
            throw NetworkError.httpError(statusCode: 401, message: "Unauthorized")
        }

        let request = EntitlementsSyncRequest(
            subscriptionTier: entitlements.subscriptionTier,
            premiumExpiresAt: entitlements.premiumExpiresAt,
            identificationCredits: entitlements.identificationCredits
        )

        let response: EntitlementsResponse = try await client.request(
            .syncUserEntitlements(request),
            bearerToken: token
        )
        return response.data.entitlements
    }

    @MainActor
    func hydrateFromServer() async {
        guard tokenStore.token != nil else { return }

        do {
            let remote = try await fetchEntitlements()
            EntitlementStore.shared.mergeFromServer(remote)
        } catch {
            // Keep the user-scoped local cache when the server is unavailable.
        }
    }

    @MainActor
    func syncEntitlementsIfPossible() async {
        guard tokenStore.token != nil else { return }

        do {
            let snapshot = EntitlementStore.shared.snapshotForSync()
            _ = try await syncEntitlements(snapshot)
        } catch {
            // Best-effort sync; local entitlements remain authoritative for purchases.
        }
    }
}

private struct EntitlementAPIServiceKey: EnvironmentKey {
    static let defaultValue = EntitlementAPIService.shared
}

extension EnvironmentValues {
    var entitlementAPIService: EntitlementAPIService {
        get { self[EntitlementAPIServiceKey.self] }
        set { self[EntitlementAPIServiceKey.self] = newValue }
    }
}
