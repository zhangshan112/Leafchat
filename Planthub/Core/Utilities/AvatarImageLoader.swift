import UIKit

// MARK: - AvatarImageLoader

enum AvatarImageLoader {
    /// Loads an avatar from a local file path, remote URL string, or `data:image/...;base64,...` value.
    static func image(from urlString: String?) -> UIImage? {
        guard let urlString = urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !urlString.isEmpty else {
            return nil
        }

        if urlString.lowercased().hasPrefix("data:") {
            return imageFromDataURL(urlString)
        }

        if let assetName = CommunityAvatarAssets.bundledAssetName(from: urlString),
           let image = UIImage(named: assetName) {
            return image
        }

        if let url = URL(string: urlString), url.isFileURL {
            return UIImage(contentsOfFile: url.path)
        }

        return nil
    }

    static func isRemoteURL(_ urlString: String) -> Bool {
        guard let scheme = URL(string: urlString)?.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    private static func imageFromDataURL(_ value: String) -> UIImage? {
        guard let commaIndex = value.firstIndex(of: ",") else { return nil }
        let base64 = String(value[value.index(after: commaIndex)...])
        guard let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }
}
