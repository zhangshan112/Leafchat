import Foundation

struct AuthUser: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let email: String?
    let username: String
    let name: String?
    let bio: String?
    let country: String?
    let avatarUrl: String?
    let createdAt: Date
    let updatedAt: Date
}

struct ProfileUpdateRequest: Encodable, Sendable {
    let username: String?
    let name: String?
    let bio: String
    let country: String
    let avatarBase64: String?
    let includesAvatar: Bool

    enum CodingKeys: String, CodingKey {
        case username
        case name
        case bio
        case country
        case avatarBase64
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let username {
            try container.encode(username, forKey: .username)
        }
        if let name {
            try container.encode(name, forKey: .name)
        }
        try container.encode(bio, forKey: .bio)
        try container.encode(country, forKey: .country)

        if includesAvatar {
            if let avatarBase64 {
                try container.encode(avatarBase64, forKey: .avatarBase64)
            } else {
                try container.encodeNil(forKey: .avatarBase64)
            }
        }
    }
}

struct AuthRegisterRequest: Codable, Sendable {
    let email: String
    let password: String
    let username: String
}

struct AuthLoginRequest: Codable, Sendable {
    let email: String
    let password: String
}

struct AuthAppleRequest: Codable, Sendable {
    let identityToken: String
    let email: String?
    let fullName: String?
}

struct AuthPayload: Codable, Sendable {
    let user: AuthUser
    let token: String
}

struct AuthResponse: Codable, Sendable {
    let data: AuthPayload
}

struct CurrentUserPayload: Codable, Sendable {
    let user: AuthUser
}

struct CurrentUserResponse: Codable, Sendable {
    let data: CurrentUserPayload
}
