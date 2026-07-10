import Foundation
import CommonCrypto

extension Data {

    func aesECBEncrypt(with key: Data) -> Data? {
        performAESOperation(operation: UInt32(kCCEncrypt), key: key)
    }

    func aesECBDecrypt(with key: Data) -> Data? {
        performAESOperation(operation: UInt32(kCCDecrypt), key: key)
    }

    private func performAESOperation(operation: UInt32, key: Data) -> Data? {
        let dataLength = self.count
        let bufferSize = dataLength + kCCBlockSizeAES128
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        var numBytesProcessed: size_t = 0

        let cryptStatus = CCCrypt(
            CCOperation(operation),
            CCAlgorithm(kCCAlgorithmAES128),
            CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode),
            key.withUnsafeBytes { $0.baseAddress },
            key.count,
            nil,
            self.withUnsafeBytes { $0.baseAddress },
            self.count,
            &buffer,
            bufferSize,
            &numBytesProcessed
        )

        guard cryptStatus == kCCSuccess else {
            return nil
        }

        return Data(bytes: buffer, count: numBytesProcessed)
    }
}
