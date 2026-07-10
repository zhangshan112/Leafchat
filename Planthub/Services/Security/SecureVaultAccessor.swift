import Foundation
import Security

struct SecureVaultAccessor {

    private static let defaultService = Bundle.main.bundleIdentifier ?? "com.default.service"

    @discardableResult
    static func setString(_ value: String, forKey key: String, service: String = defaultService) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return setData(data, forKey: key, service: service)
    }

    static func string(forKey key: String, service: String = defaultService) -> String? {
        guard let data = data(forKey: key, service: service) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func setData(_ data: Data, forKey key: String, service: String = defaultService) -> Bool {
        let query = baseQuery(forKey: key, service: service)

        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    static func data(forKey key: String, service: String = defaultService) -> Data? {
        var query = baseQuery(forKey: key, service: service)
        query[kSecReturnData as String] = true

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return data
    }

    @discardableResult
    static func removeItem(forKey key: String, service: String = defaultService) -> Bool {
        let query = baseQuery(forKey: key, service: service)
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private static func baseQuery(forKey key: String, service: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}
