import Foundation
import Observation

@MainActor
@Observable
final class EntitlementStore {
    static let shared = EntitlementStore()

    static let freeIdentificationsPerMonth = 3
    static let basicIdentificationsPerMonth = 30
    static let freePostsPerMonth = 10
    static let basicPostsPerMonth = 50

    private(set) var subscriptionTier: SubscriptionTier = .none
    private(set) var premiumExpiresAt: Date?
    private(set) var identificationCredits = 0
    private(set) var freeIdentificationsUsedThisMonth = 0
    private(set) var basicIdentificationsUsedThisMonth = 0
    private(set) var postsPublishedThisMonth = 0

    /// In-flight purchase intent when multiple paywall items share one StoreKit SKU.
    private(set) var pendingSubscriptionTier: SubscriptionTier?
    private(set) var pendingConsumableCredits: Int?

    /// Last tier granted from a subscription purchase (used when test SKU is shared).
    private(set) var lastGrantedSubscriptionTier: SubscriptionTier = .advanced

    /// Advanced tier — unlimited identification and Plus badge.
    var isPremium: Bool { subscriptionTier == .advanced }

    /// Any paid subscription (Basic or Advanced).
    var hasActiveSubscription: Bool { subscriptionTier != .none }

    private let defaults: UserDefaults
    private let defaultsPrefix = "leafchat.entitlements."
    private var storageUserID = "anonymous"

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadFromDefaults()
    }

    func reload(for userId: String?) {
        storageUserID = userId ?? "anonymous"
        loadFromDefaults()
    }

    // MARK: - Feature access

    func canAccess(_ feature: EntitlementFeature) -> Bool {
        switch feature {
        case .fullEncyclopedia:
            return true
        case .plantIdentification, .savedPosts, .premiumPlots:
            return subscriptionTier == .advanced
        }
    }

    func identificationAccess() -> IdentificationAccess {
        if subscriptionTier == .advanced { return .unlimited }
        if remainingBasicIdentifications > 0 { return .basicQuota }
        if identificationCredits > 0 { return .consumableCredit }
        if remainingFreeIdentifications > 0 { return .freeQuota }
        return .denied
    }

    var remainingFreeIdentifications: Int {
        max(0, Self.freeIdentificationsPerMonth - freeIdentificationsUsedThisMonth)
    }

    var remainingBasicIdentifications: Int {
        guard subscriptionTier == .basic else { return 0 }
        return max(0, Self.basicIdentificationsPerMonth - basicIdentificationsUsedThisMonth)
    }

    var monthlyPostLimit: Int? {
        switch subscriptionTier {
        case .none:
            return Self.freePostsPerMonth
        case .basic:
            return Self.basicPostsPerMonth
        case .advanced:
            return nil
        }
    }

    var remainingPostsThisMonth: Int? {
        guard let monthlyPostLimit else { return nil }
        return max(0, monthlyPostLimit - postsPublishedThisMonth)
    }

    func canPublishPost() -> Bool {
        guard let remainingPostsThisMonth else { return true }
        return remainingPostsThisMonth > 0
    }

    func consumePostQuotaIfNeeded() {
        guard subscriptionTier != .advanced else { return }
        postsPublishedThisMonth += 1
        persist()
    }

    func consumeIdentificationCreditIfNeeded() {
        guard subscriptionTier != .advanced else { return }

        if remainingBasicIdentifications > 0 {
            basicIdentificationsUsedThisMonth += 1
            persist()
            return
        }

        if identificationCredits > 0 {
            identificationCredits -= 1
            persist()
            scheduleSync()
            return
        }

        if freeIdentificationsUsedThisMonth < Self.freeIdentificationsPerMonth {
            freeIdentificationsUsedThisMonth += 1
            persist()
        }
    }

    // MARK: - Purchase intent (shared test SKU)

    func setPurchaseIntent(subscriptionTier tier: SubscriptionTier) {
        pendingSubscriptionTier = tier
        pendingConsumableCredits = nil
    }

    func setPurchaseIntent(consumableCredits credits: Int) {
        pendingConsumableCredits = credits
        pendingSubscriptionTier = nil
    }

    func clearPurchaseIntent() {
        pendingSubscriptionTier = nil
        pendingConsumableCredits = nil
    }

    func resolvedTestSubscriptionTier() -> SubscriptionTier {
        pendingSubscriptionTier ?? lastGrantedSubscriptionTier
    }

    // MARK: - StoreKit application

    func applySubscription(tier: SubscriptionTier, expirationDate: Date?) {
        guard tier > .none else { return }
        if tier >= subscriptionTier {
            subscriptionTier = tier
        }
        lastGrantedSubscriptionTier = tier
        if let expirationDate {
            premiumExpiresAt = expirationDate
        }
        persist()
        scheduleSync()
    }

    func clearSubscription() {
        subscriptionTier = .none
        premiumExpiresAt = nil
        persist()
        scheduleSync()
    }

    func addIdentificationCredits(_ amount: Int) {
        guard amount > 0 else { return }
        identificationCredits += amount
        persist()
        scheduleSync()
    }

    func refreshFromStoreKit(tier: SubscriptionTier, expirationDate: Date?) {
        if tier == .none {
            clearSubscription()
        } else {
            subscriptionTier = tier
            premiumExpiresAt = expirationDate
            persist()
            scheduleSync()
        }
    }

    func mergeFromServer(_ remote: UserEntitlements) {
        if remote.subscriptionTier > subscriptionTier {
            subscriptionTier = remote.subscriptionTier
            premiumExpiresAt = remote.premiumExpiresAt
        }

        identificationCredits = max(identificationCredits, remote.identificationCredits)
        persist()
    }

    func snapshotForSync() -> UserEntitlements {
        UserEntitlements(
            subscriptionTier: subscriptionTier,
            premiumExpiresAt: premiumExpiresAt,
            identificationCredits: identificationCredits,
            updatedAt: Date()
        )
    }

    // MARK: - Persistence

    private func loadFromDefaults() {
        if let raw = defaults.string(forKey: key("subscriptionTier")),
           let tier = SubscriptionTier(rawValue: raw) {
            subscriptionTier = tier
        } else if defaults.bool(forKey: key("isPremium")) {
            subscriptionTier = .advanced
        } else {
            subscriptionTier = .none
        }

        if let raw = defaults.string(forKey: key("lastGrantedSubscriptionTier")),
           let tier = SubscriptionTier(rawValue: raw) {
            lastGrantedSubscriptionTier = tier
        } else {
            lastGrantedSubscriptionTier = .advanced
        }

        premiumExpiresAt = defaults.object(forKey: key("premiumExpiresAt")) as? Date
        identificationCredits = defaults.integer(forKey: key("identificationCredits"))
        freeIdentificationsUsedThisMonth = defaults.integer(forKey: key("freeIdentificationsUsed"))
        basicIdentificationsUsedThisMonth = defaults.integer(forKey: key("basicIdentificationsUsed"))
        postsPublishedThisMonth = defaults.integer(forKey: key("postsPublishedThisMonth"))

        let currentMonth = Self.currentMonthKey()

        let storedFreeIDMonth = defaults.string(forKey: key("freeIdentificationMonth")) ?? ""
        if storedFreeIDMonth != currentMonth {
            freeIdentificationsUsedThisMonth = 0
            defaults.set(currentMonth, forKey: key("freeIdentificationMonth"))
        }

        let storedBasicIDMonth = defaults.string(forKey: key("basicIdentificationMonth")) ?? ""
        if storedBasicIDMonth != currentMonth {
            basicIdentificationsUsedThisMonth = 0
            defaults.set(currentMonth, forKey: key("basicIdentificationMonth"))
        }

        let storedPostMonth = defaults.string(forKey: key("postQuotaMonth")) ?? ""
        if storedPostMonth != currentMonth {
            postsPublishedThisMonth = 0
            defaults.set(currentMonth, forKey: key("postQuotaMonth"))
        }
    }

    private func persist() {
        defaults.set(subscriptionTier.rawValue, forKey: key("subscriptionTier"))
        defaults.set(isPremium, forKey: key("isPremium"))
        defaults.set(lastGrantedSubscriptionTier.rawValue, forKey: key("lastGrantedSubscriptionTier"))
        defaults.set(premiumExpiresAt, forKey: key("premiumExpiresAt"))
        defaults.set(identificationCredits, forKey: key("identificationCredits"))
        defaults.set(freeIdentificationsUsedThisMonth, forKey: key("freeIdentificationsUsed"))
        defaults.set(basicIdentificationsUsedThisMonth, forKey: key("basicIdentificationsUsed"))
        defaults.set(postsPublishedThisMonth, forKey: key("postsPublishedThisMonth"))

        let currentMonth = Self.currentMonthKey()
        defaults.set(currentMonth, forKey: key("freeIdentificationMonth"))
        defaults.set(currentMonth, forKey: key("basicIdentificationMonth"))
        defaults.set(currentMonth, forKey: key("postQuotaMonth"))
    }

    func clearLocalState() {
        subscriptionTier = .none
        premiumExpiresAt = nil
        identificationCredits = 0
        freeIdentificationsUsedThisMonth = 0
        basicIdentificationsUsedThisMonth = 0
        postsPublishedThisMonth = 0
        pendingSubscriptionTier = nil
        pendingConsumableCredits = nil
        persist()
    }

    private func key(_ suffix: String) -> String {
        "\(defaultsPrefix)\(storageUserID).\(suffix)"
    }

    private static func currentMonthKey() -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: Date())
        let year = components.year ?? 0
        let month = components.month ?? 0
        return String(format: "%04d-%02d", year, month)
    }

    private func scheduleSync() {
        Task {
            await EntitlementAPIService.shared.syncEntitlementsIfPossible()
        }
    }
}
