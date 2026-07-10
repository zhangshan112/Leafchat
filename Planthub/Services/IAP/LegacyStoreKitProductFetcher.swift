import Foundation
import StoreKit

enum LegacyStoreKitProductFetcher {

    struct FetchResult {
        let products: [SKProduct]
        let invalidProductIdentifiers: [String]
        let errorDescription: String?
    }

    @MainActor private static var activeSessions: [ObjectIdentifier: DelegateSession] = [:]

    @MainActor
    static func fetchSKProducts(identifiers: Set<String>) async -> FetchResult {
        guard !identifiers.isEmpty else {
            return FetchResult(products: [], invalidProductIdentifiers: [], errorDescription: nil)
        }
        let session = DelegateSession()
        let key = ObjectIdentifier(session)
        activeSessions[key] = session
        session.onFinish = {
            activeSessions[key] = nil
        }
        return await session.run(identifiers: identifiers)
    }

    private final class DelegateSession: NSObject, SKProductsRequestDelegate {

        var onFinish: (() -> Void)?

        private var continuation: CheckedContinuation<FetchResult, Never>?
        private var activeRequest: SKProductsRequest?

        func run(identifiers: Set<String>) async -> FetchResult {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                let req = SKProductsRequest(productIdentifiers: identifiers)
                self.activeRequest = req
                req.delegate = self
                req.start()
            }
        }

        func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
            finish(
                with: FetchResult(
                    products: response.products,
                    invalidProductIdentifiers: response.invalidProductIdentifiers,
                    errorDescription: nil
                )
            )
        }

        func request(_ request: SKRequest, didFailWithError error: Error) {
            finish(
                with: FetchResult(
                    products: [],
                    invalidProductIdentifiers: [],
                    errorDescription: error.localizedDescription
                )
            )
        }

        func requestDidFinish(_ request: SKRequest) {}

        private func finish(with result: FetchResult) {
            Task { @MainActor in
                self.continuation?.resume(returning: result)
                self.continuation = nil
                self.activeRequest = nil
                self.onFinish?()
                self.onFinish = nil
            }
        }
    }
}
