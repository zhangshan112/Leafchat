import Foundation
import Security

/// Persists the auth session token in the Keychain for secure, encrypted storage.
/// Token is device-only and removed when the app is uninstalled.
final class AuthTokenStore: @unchecked Sendable {
    static let shared = AuthTokenStore()

    private let keychainService = "com.planthub.auth"
    private let keychainAccount = "sessionToken"
    private let legacyDefaultsKey = "com.planthub.auth.sessionToken"

    private init() {
        migrateLegacyDefaultsToken()
    }

    var token: String? {
        readFromKeychain()
    }

    func save(_ token: String) {
        writeToKeychain(token)
    }

    func clear() {
        deleteFromKeychain()
    }

    // MARK: - Keychain

    private func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func writeToKeychain(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        let update: [String: Any] = [
            kSecValueData as String: data,
        ]

        if SecItemUpdate(query as CFDictionary, update as CFDictionary) == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    private func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Migrates tokens written by older builds that stored sessions in UserDefaults.
    private func migrateLegacyDefaultsToken() {
        guard let legacyToken = UserDefaults.standard.string(forKey: legacyDefaultsKey) else { return }
        writeToKeychain(legacyToken)
        UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
    }
}
