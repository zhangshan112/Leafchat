import Foundation

/// Persists the signed-in user profile locally for offline reads between app launches.
final class LocalAuthUserStore: @unchecked Sendable {
    static let shared = LocalAuthUserStore()

    private let defaultsKey = "planthub.localAuthUser"

    private init() {}

    func load() -> AuthUser? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            return nil
        }

        return try? JSONDecoder().decode(AuthUser.self, from: data)
    }

    func save(_ user: AuthUser) {
        guard let data = try? JSONEncoder().encode(user) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
