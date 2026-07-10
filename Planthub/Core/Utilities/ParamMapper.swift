import Foundation

struct ParamMapper {
    static var k: K { K() }

    static func decrypt(_ obfuscatedParams: [String: Any]) -> [String: Any] {
        var realParams: [String: Any] = [:]
        for (obfuscatedKey, value) in obfuscatedParams {
            realParams[decryptKey(obfuscatedKey)] = value
        }
        return realParams
    }

    /// Position-dependent add + rolling XOR, then hex. Differs from base XOR+Base64 scheme.
    private static let mask: [UInt8] = [0xA3, 0x5C, 0x19, 0xE7]

    private static func decryptKey(_ obfuscated: String) -> String {
        guard let data = Data(labsHexString: obfuscated), !data.isEmpty else {
            return obfuscated
        }
        let plain = data.enumerated().map { index, byte -> UInt8 in
            let xored = byte ^ mask[index % mask.count]
            let delta = UInt8((index &* 3 &+ 0x29) & 0xFF)
            return xored &- delta
        }
        return String(data: Data(plain), encoding: .utf8) ?? obfuscated
    }
}

struct K {
    let a1 = "2ecdbc7c3bc1834006"
    let a2 = "3acb8f"
    let a3 = "2fc4817000f0835305eaa3541fe2"
    let a4 = "2ecdbc7c3bc1834c13f4b5"
    let a5 = "2ecdbc7c3bc1834b01edb5"
    let a6 = "3ff9bb4139f9835305eaa3541fe2"
    let a7 = "36d1847e09c5bb44"
    let a8 = "00c78470"
    let a9 = "32d1bb7608f4b0"
    let a10 = "32d1bb7606f6b35119"
    let a11 = "3bc0ba7004c5b64a10"
    let a12 = "31c397423df9a94d01e4af5b"
    let a13 = "37cdb17307c5b445"
    let a14 = "34cdba4e07f6bf"
    let a15 = "3ff9bb4139f9834d01eeb7580deba12e"
}

private extension Data {
    init?(labsHexString: String) {
        let hex = labsHexString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hex.count % 2 == 0, !hex.isEmpty else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }
}
