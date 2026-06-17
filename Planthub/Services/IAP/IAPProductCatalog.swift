import Foundation

enum SubscriptionTier: String, Codable, Sendable, Comparable {
    case none
    case basic
    case advanced

    private var rank: Int {
        switch self {
        case .none: 0
        case .basic: 1
        case .advanced: 2
        }
    }

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.rank < rhs.rank
    }

    var displayName: String {
        switch self {
        case .none: "Free"
        case .basic: "LeafChat Basic"
        case .advanced: "LeafChat Plus"
        }
    }
}

enum IAPProductCatalog {
    static let subscriptionGroupID = "membership"

    struct SubscriptionListing: Identifiable, Sendable {
        let id: String
        let tier: SubscriptionTier
        let title: String
        let subtitle: String
        let referencePrice: String
        let sortOrder: Int

        var periodLabel: String {
            id.contains("weekly") ? "Weekly" : "Monthly"
        }
    }

    struct ConsumableListing: Identifiable, Sendable {
        let id: String
        let credits: Int
        let referencePrice: String

        var title: String { "\(credits) Credits" }
    }

    static let subscriptionListings: [SubscriptionListing] = [
        SubscriptionListing(
            id: "com.plus.basic.weekly",
            tier: .basic,
            title: "Basic Weekly",
            subtitle: "More monthly posts + member identification quota",
            referencePrice: "$4.99",
            sortOrder: 0
        ),
        SubscriptionListing(
            id: "com.plus.basic.monthly",
            tier: .basic,
            title: "Basic Monthly",
            subtitle: "More monthly posts + member identification quota",
            referencePrice: "$9.99",
            sortOrder: 1
        ),
        SubscriptionListing(
            id: "com.plus.advanced.weekly",
            tier: .advanced,
            title: "Plus Weekly",
            subtitle: "Unlimited posts + unlimited AI identification + badge",
            referencePrice: "$9.99",
            sortOrder: 2
        ),
        SubscriptionListing(
            id: "com.plus.advanced.monthly",
            tier: .advanced,
            title: "Plus Monthly",
            subtitle: "Unlimited posts + unlimited AI identification + badge",
            referencePrice: "$16.99",
            sortOrder: 3
        ),
    ]

    static let consumableListings: [ConsumableListing] = [
        ConsumableListing(id: "com.credits.92", credits: 92, referencePrice: "$1.99"),
        ConsumableListing(id: "com.credits.138", credits: 138, referencePrice: "$2.99"),
        ConsumableListing(id: "com.credits.183", credits: 183, referencePrice: "$3.99"),
        ConsumableListing(id: "com.credits.252", credits: 252, referencePrice: "$4.99"),
        ConsumableListing(id: "com.credits.328", credits: 328, referencePrice: "$6.99"),
        ConsumableListing(id: "com.credits.470", credits: 470, referencePrice: "$9.99"),
        ConsumableListing(id: "com.credits.930", credits: 930, referencePrice: "$16.99"),
        ConsumableListing(id: "com.credits.1454", credits: 1454, referencePrice: "$28.99"),
        ConsumableListing(id: "com.credits.2239", credits: 2239, referencePrice: "$39.99"),
        ConsumableListing(id: "com.credits.3131", credits: 3131, referencePrice: "$52.99"),
        ConsumableListing(id: "com.credits.4635", credits: 4635, referencePrice: "$75.99"),
        ConsumableListing(id: "com.credits.6632", credits: 6632, referencePrice: "$98.99"),
    ]

    /// Product IDs sent to StoreKit `Product.products(for:)`.
    static var storeProductIDs: [String] {
        if IAPConfig.useTestProductCatalog {
            return [IAPConfig.testVIPProductID, IAPConfig.testCoinProductID]
        }

        let subscriptionIDs = subscriptionListings.map(\.id)
        let consumableIDs = consumableListings.map(\.id)
        return subscriptionIDs + consumableIDs
    }

    /// Maps a paywall listing ID to the SKU that is actually purchased.
    static func storeProductID(for displayProductID: String) -> String? {
        if IAPConfig.useTestProductCatalog {
            if subscriptionListings.contains(where: { $0.id == displayProductID }) {
                return IAPConfig.testVIPProductID
            }
            if consumableListings.contains(where: { $0.id == displayProductID }) {
                return IAPConfig.testCoinProductID
            }
            return nil
        }

        if subscriptionListings.contains(where: { $0.id == displayProductID })
            || consumableListings.contains(where: { $0.id == displayProductID }) {
            return displayProductID
        }
        return nil
    }

    static func subscriptionListing(for displayProductID: String) -> SubscriptionListing? {
        subscriptionListings.first { $0.id == displayProductID }
    }

    static func consumableListing(for displayProductID: String) -> ConsumableListing? {
        consumableListings.first { $0.id == displayProductID }
    }

    static func subscriptionTier(for displayProductID: String) -> SubscriptionTier? {
        subscriptionListing(for: displayProductID)?.tier
    }

    static func identificationCredits(for displayProductID: String) -> Int? {
        consumableListing(for: displayProductID)?.credits
    }

    static func isSubscriptionStoreProduct(_ productID: String) -> Bool {
        if IAPConfig.useTestProductCatalog {
            return productID == IAPConfig.testVIPProductID
        }
        return subscriptionListings.contains { $0.id == productID }
    }

    static func isConsumableStoreProduct(_ productID: String) -> Bool {
        if IAPConfig.useTestProductCatalog {
            return productID == IAPConfig.testCoinProductID
        }
        return consumableListings.contains { $0.id == productID }
    }

    static var basicSubscriptionListings: [SubscriptionListing] {
        subscriptionListings.filter { $0.tier == .basic }
    }

    static var advancedSubscriptionListings: [SubscriptionListing] {
        subscriptionListings.filter { $0.tier == .advanced }
    }
}
