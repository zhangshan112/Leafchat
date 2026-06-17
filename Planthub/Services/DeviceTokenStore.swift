import Foundation
import Security

/// Persists the APNs device token in the Keychain for reuse across app launches.
final class DeviceTokenStore: @unchecked Sendable {
    static let shared = DeviceTokenStore()

    private let service = "com.planthub.push"
    private let account = "deviceToken"

    private init() {}

    var token: String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data
        else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func save(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }

        clear()

        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        query[kSecAttrSynchronizable as String] = kCFBooleanFalse

        SecItemAdd(query as CFDictionary, nil)
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
    }
}
