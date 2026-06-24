import Foundation
import StoreKit

enum IAPError: LocalizedError {
    case productNotFound
    case networkUnavailable
    case purchasePending
    case purchaseCancelled
    case verificationFailed
    case subscriptionAlreadyActive

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            "This product is not available."
        case .networkUnavailable:
            "Network error. Please try again."
        case .purchasePending:
            "Your purchase is pending approval."
        case .purchaseCancelled:
            "Purchase was cancelled."
        case .verificationFailed:
            "We could not verify your purchase. Please try again."
        case .subscriptionAlreadyActive:
            "You already have an active subscription. Manage or change your plan in Settings > Apple ID > Subscriptions."
        }
    }
}

@MainActor
@Observable
final class IAPManager {
    static let shared = IAPManager()

    private(set) var storeProducts: [String: Product] = [:]
    private(set) var isLoadingProducts = false
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
    private(set) var lastErrorMessage: String?

    private var updatesTask: Task<Void, Never>?
    private let entitlementStore: EntitlementStore

    private init(entitlementStore: EntitlementStore = .shared) {
        self.entitlementStore = entitlementStore
    }

    func storeProduct(id: String) -> Product? {
        storeProducts[id]
    }

    func start() {
        guard updatesTask == nil else { return }

        updatesTask = Task {
            for await result in Transaction.updates {
                guard entitlementStore.pendingSubscriptionTier != nil ||
                      entitlementStore.pendingConsumableCredits != nil else {
                    continue
                }
                await handle(transactionResult: result, finish: true)
            }
        }

        Task {
            await loadProducts()
        }
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let loaded = try await Product.products(for: IAPProductCatalog.storeProductIDs)
            for product in loaded {
                storeProducts[product.id] = product
            }
        } catch {
            // Prefetch failures are silent; purchase flow surfaces errors to the user.
        }
    }

    func purchase(displayProductID: String) async throws {
        guard IAPProductCatalog.storeProductID(for: displayProductID) != nil else {
            throw IAPError.productNotFound
        }

        if IAPProductCatalog.subscriptionTier(for: displayProductID) != nil,
           entitlementStore.hasActiveSubscription {
            throw IAPError.subscriptionAlreadyActive
        }

        isPurchasing = true
        defer {
            isPurchasing = false
            entitlementStore.clearPurchaseIntent()
        }

        let product = try await resolveStoreProduct(forDisplayProductID: displayProductID)

        if let tier = IAPProductCatalog.subscriptionTier(for: displayProductID) {
            entitlementStore.setPurchaseIntent(subscriptionTier: tier)
        } else if let credits = IAPProductCatalog.identificationCredits(for: displayProductID) {
            entitlementStore.setPurchaseIntent(consumableCredits: credits)
        }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            await handle(transactionResult: verification, finish: true)
            lastErrorMessage = nil
        case .userCancelled:
            throw IAPError.purchaseCancelled
        case .pending:
            throw IAPError.purchasePending
        @unknown default:
            throw IAPError.purchasePending
        }
    }

    /// Returns a cached StoreKit product, fetching from the App Store once on demand if needed.
    private func resolveStoreProduct(forDisplayProductID displayProductID: String) async throws -> Product {
        guard let storeProductID = IAPProductCatalog.storeProductID(for: displayProductID) else {
            throw IAPError.productNotFound
        }

        if let product = storeProducts[storeProductID] {
            return product
        }

        return try await fetchStoreProduct(id: storeProductID)
    }

    private func fetchStoreProduct(id storeProductID: String) async throws -> Product {
        do {
            let loaded = try await Product.products(for: [storeProductID])
            guard let product = loaded.first(where: { $0.id == storeProductID }) else {
                throw IAPError.productNotFound
            }
            storeProducts[storeProductID] = product
            return product
        } catch let error as IAPError {
            throw error
        } catch {
            if Self.isNetworkError(error) {
                throw IAPError.networkUnavailable
            }
            throw IAPError.productNotFound
        }
    }

    private static func isNetworkError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .timedOut,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .dnsLookupFailed,
                 .internationalRoamingOff,
                 .dataNotAllowed:
                return true
            default:
                return false
            }
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
    }

    func restorePurchases() async {
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await refreshEntitlementsFromStoreKit()
            lastErrorMessage = nil
            await EntitlementAPIService.shared.syncEntitlementsIfPossible()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func refreshEntitlementsFromStoreKit() async {
        var bestTier: SubscriptionTier = .none
        var latestExpiration: Date?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard IAPProductCatalog.isSubscriptionStoreProduct(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }

            let isActive: Bool
            if let expiration = transaction.expirationDate {
                isActive = expiration > Date()
            } else {
                isActive = true
            }

            guard isActive else { continue }

            let tier: SubscriptionTier
            if IAPConfig.useTestProductCatalog, transaction.productID == IAPConfig.testVIPProductID {
                tier = entitlementStore.resolvedTestSubscriptionTier()
            } else if let mapped = IAPProductCatalog.subscriptionTier(for: transaction.productID) {
                tier = mapped
            } else {
                continue
            }

            if tier > bestTier {
                bestTier = tier
                latestExpiration = transaction.expirationDate
            } else if tier == bestTier {
                if let expiration = transaction.expirationDate {
                    if let current = latestExpiration {
                        latestExpiration = max(current, expiration)
                    } else {
                        latestExpiration = expiration
                    }
                }
            }
        }

        entitlementStore.refreshFromStoreKit(tier: bestTier, expirationDate: latestExpiration)
    }

    // MARK: - Private

    private func handle(transactionResult: VerificationResult<Transaction>, finish: Bool) async {
        guard case .verified(let transaction) = transactionResult else {
            lastErrorMessage = IAPError.verificationFailed.errorDescription
            return
        }

        if IAPProductCatalog.isSubscriptionStoreProduct(transaction.productID) {
            if transaction.revocationDate != nil {
                await refreshEntitlementsFromStoreKit()
            } else if let expiration = transaction.expirationDate, expiration <= Date() {
                await refreshEntitlementsFromStoreKit()
            } else {
                let tier: SubscriptionTier
                if IAPConfig.useTestProductCatalog, transaction.productID == IAPConfig.testVIPProductID {
                    tier = entitlementStore.resolvedTestSubscriptionTier()
                } else if let mapped = IAPProductCatalog.subscriptionTier(for: transaction.productID) {
                    tier = mapped
                } else {
                    tier = .advanced
                }
                entitlementStore.applySubscription(tier: tier, expirationDate: transaction.expirationDate)
            }
        } else if IAPProductCatalog.isConsumableStoreProduct(transaction.productID) {
            let credits: Int
            if IAPConfig.useTestProductCatalog, transaction.productID == IAPConfig.testCoinProductID {
                credits = entitlementStore.pendingConsumableCredits ?? 0
            } else if let mapped = IAPProductCatalog.identificationCredits(for: transaction.productID) {
                credits = mapped
            } else {
                credits = 0
            }

            if credits > 0 {
                entitlementStore.addIdentificationCredits(credits)
            }
        }

        if finish {
            await transaction.finish()
        }

        await EntitlementAPIService.shared.syncEntitlementsIfPossible()
    }
}
