import Foundation

struct DefenseKit {

    static func encryptData(_ data: Data, withKey key: String) -> Data? {
        guard !data.isEmpty else { return data }
        guard let keyData = key.data(using: .ascii) else { return nil }

        guard let encryptedData = data.aesECBEncrypt(with: keyData) else { return nil }

        let base64String = encryptedData.base64EncodedString(options: [])

        return base64String.data(using: .utf8)
    }

    static func decryptData(_ data: Data, withKey key: String) -> Data? {
        guard let keyData = key.data(using: .ascii) else { return nil }

        guard let base64String = String(data: data, encoding: .utf8) else { return nil }

        guard let base64Data = Data(base64Encoded: base64String, options: []) else { return nil }

        return base64Data.aesECBDecrypt(with: keyData)
    }

    static func encryptDataToString(_ data: Data, withKey key: String) -> String? {
        guard let encryptedData = encryptData(data, withKey: key) else { return nil }
        return encryptedData.base64EncodedString(options: [])
    }

    static func decryptStringToData(_ base64String: String, withKey key: String) -> Data? {
        guard let encryptedData = Data(base64Encoded: base64String) else { return nil }
        return decryptData(encryptedData, withKey: key)
    }
}
