import Foundation

// MARK: - Feature gates

enum EntitlementFeature: String, Sendable {
    case fullEncyclopedia
    case plantIdentification
    case savedPosts
    case premiumPlots
}

enum IdentificationAccess: Equatable, Sendable {
    case unlimited
    case basicQuota
    case consumableCredit
    case freeQuota
    case denied
}

enum PaywallSource: String, Sendable {
    case settings
    case encyclopedia
    case identification
    case membership
}

// MARK: - Sync payload

struct UserEntitlements: Codable, Sendable, Equatable {
    var subscriptionTier: SubscriptionTier
    var premiumExpiresAt: Date?
    var identificationCredits: Int
    var updatedAt: Date?

    /// Advanced-tier alias kept for API backward compatibility.
    var isPremium: Bool {
        subscriptionTier == .advanced
    }

    static let empty = UserEntitlements(
        subscriptionTier: .none,
        premiumExpiresAt: nil,
        identificationCredits: 0,
        updatedAt: nil
    )

    enum CodingKeys: String, CodingKey {
        case subscriptionTier
        case isPremium
        case premiumExpiresAt
        case identificationCredits
        case updatedAt
    }

    init(
        subscriptionTier: SubscriptionTier,
        premiumExpiresAt: Date?,
        identificationCredits: Int,
        updatedAt: Date?
    ) {
        self.subscriptionTier = subscriptionTier
        self.premiumExpiresAt = premiumExpiresAt
        self.identificationCredits = identificationCredits
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        premiumExpiresAt = try container.decodeIfPresent(Date.self, forKey: .premiumExpiresAt)
        identificationCredits = try container.decodeIfPresent(Int.self, forKey: .identificationCredits) ?? 0
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)

        if let tier = try container.decodeIfPresent(SubscriptionTier.self, forKey: .subscriptionTier) {
            subscriptionTier = tier
        } else if try container.decodeIfPresent(Bool.self, forKey: .isPremium) == true {
            subscriptionTier = .advanced
        } else {
            subscriptionTier = .none
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(subscriptionTier, forKey: .subscriptionTier)
        try container.encode(isPremium, forKey: .isPremium)
        try container.encode(identificationCredits, forKey: .identificationCredits)
        try container.encodeIfPresent(premiumExpiresAt, forKey: .premiumExpiresAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

struct EntitlementsResponse: Decodable, Sendable {
    let data: EntitlementsPayload
}

struct EntitlementsPayload: Decodable, Sendable {
    let entitlements: UserEntitlements
}

struct EntitlementsSyncRequest: Encodable, Sendable {
    let subscriptionTier: SubscriptionTier
    let premiumExpiresAt: Date?
    let identificationCredits: Int

    enum CodingKeys: String, CodingKey {
        case subscriptionTier
        case isPremium
        case premiumExpiresAt
        case identificationCredits
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(subscriptionTier, forKey: .subscriptionTier)
        try container.encode(subscriptionTier == .advanced, forKey: .isPremium)
        try container.encode(identificationCredits, forKey: .identificationCredits)

        if let premiumExpiresAt {
            try container.encode(
                ISO8601DateFormatter.fractional.string(from: premiumExpiresAt),
                forKey: .premiumExpiresAt
            )
        } else {
            try container.encodeNil(forKey: .premiumExpiresAt)
        }
    }
}

private extension ISO8601DateFormatter {
    static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
