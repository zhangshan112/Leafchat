import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
}

enum APIEndpoint {
    case health
    case authRegister(AuthRegisterRequest)
    case authLogin(AuthLoginRequest)
    case authApple(AuthAppleRequest)
    case authMe
    case authUpdateProfile(ProfileUpdateRequest)
    case authLogout
    case authDeleteAccount
    case registerPushToken(RegisterPushTokenRequest)
    case plants(userId: String?)
    case createPlant(CreatePlantRequest)
    case userEntitlements
    case syncUserEntitlements(EntitlementsSyncRequest)

    var path: String {
        switch self {
        case .health:
            "/api/health"
        case .authRegister:
            "/api/auth/register"
        case .authLogin:
            "/api/auth/login"
        case .authApple:
            "/api/auth/apple"
        case .authMe, .authUpdateProfile:
            "/api/auth/me"
        case .authLogout:
            "/api/auth/logout"
        case .authDeleteAccount:
            "/api/auth/delete-account"
        case .registerPushToken:
            "/api/devices/push-token"
        case .plants, .createPlant:
            "/api/plants"
        case .userEntitlements, .syncUserEntitlements:
            "/api/user/entitlements"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .health, .authMe, .plants, .userEntitlements:
            .get
        case .authUpdateProfile, .syncUserEntitlements:
            .patch
        case .authRegister, .authLogin, .authApple, .authLogout, .authDeleteAccount, .createPlant, .registerPushToken:
            .post
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case let .plants(userId):
            guard let userId, !userId.isEmpty else { return nil }
            return [URLQueryItem(name: "userId", value: userId)]
        case .health, .authRegister, .authLogin, .authApple, .authMe, .authLogout, .authDeleteAccount, .createPlant, .registerPushToken, .authUpdateProfile, .userEntitlements, .syncUserEntitlements:
            return nil
        }
    }
}
