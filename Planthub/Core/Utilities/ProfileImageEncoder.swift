import UIKit

// MARK: - ProfileImageEncoder

enum ProfileImageEncoder {
    /// Server-side hard limit is 512 KB; keep slight headroom for safer uploads.
    static let maxUploadBytes = 500 * 1024

    /// Attempts from higher to lower visual quality.
    private static let qualityCandidates: [CGFloat] = [0.84, 0.74, 0.64, 0.54, 0.46, 0.38, 0.30, 0.24, 0.18]

    /// Attempts from larger to smaller image dimensions.
    private static let maxDimensionCandidates: [CGFloat] = [1024, 896, 768, 640, 512, 448, 384, 320, 256]

    /// Encodes a profile photo as raw base64 JPEG suitable for `PATCH /api/auth/me`.
    static func jpegBase64(from image: UIImage) -> String? {
        for maxDimension in maxDimensionCandidates {
            let resized = image.resizedForProfileUpload(maxDimension: maxDimension)

            for quality in qualityCandidates {
                guard let data = resized.jpegData(compressionQuality: quality) else { continue }

                if data.count <= maxUploadBytes {
                    return data.base64EncodedString()
                }
            }
        }

        // Could not reach upload-safe size.
        return nil
    }
}

private extension UIImage {
    func resizedForProfileUpload(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }

        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
