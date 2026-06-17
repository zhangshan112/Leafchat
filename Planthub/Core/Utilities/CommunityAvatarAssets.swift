import Foundation

// MARK: - CommunityAvatarAssets

/// Bundled photorealistic avatars for mock community gardeners (u1–u16).
enum CommunityAvatarAssets {
    static let scheme = "asset"

    static func assetName(forUserId id: String) -> String? {
        guard id.hasPrefix("u"),
              let number = Int(id.dropFirst()),
              (1...16).contains(number) else {
            return nil
        }
        return "community-avatar-\(id)"
    }

    static func avatarUrlString(forUserId id: String) -> String? {
        guard let assetName = assetName(forUserId: id) else { return nil }
        return "\(scheme)://\(assetName)"
    }

    static func avatarURL(forUserId id: String) -> URL? {
        guard let urlString = avatarUrlString(forUserId: id) else { return nil }
        return URL(string: urlString)
    }

    static func isBundledAssetReference(_ value: String) -> Bool {
        value.lowercased().hasPrefix("\(scheme)://")
    }

    static func bundledAssetName(from value: String) -> String? {
        let prefix = "\(scheme)://"
        guard value.lowercased().hasPrefix(prefix) else { return nil }
        return String(value.dropFirst(prefix.count))
    }
}
