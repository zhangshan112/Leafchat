import SwiftUI

// MARK: - View model

struct PlantCardData: Identifiable {
    let id: String
    let name: String
    let coverImageAssetName: String?
    let collectorsCount: Int
    let postsCount: Int
}

// MARK: - PlantCard

/// Tappable plant card: 1:1 bundled image with corner radius 16, plant name,
/// collectors count, and posts count.
struct PlantCard: View {

    let plant: PlantCardData
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button { onTap?() } label: {
            VStack(alignment: .leading, spacing: 8) {
                coverImage
                infoSection
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Private

    private var coverImage: some View {
        Group {
            if let assetName = plant.coverImageAssetName {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.phSurface
                    .overlay(
                        Image(systemName: "tree")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.textSecondary)
                    )
            }
        }
        .mediaContainer(aspectRatio: 1.0)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plant.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            HStack(spacing: 10) {
                Label(countString(plant.collectorsCount), systemImage: "person.2")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)

                Label(countString(plant.postsCount), systemImage: "photo.on.rectangle")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.horizontal, 2)
    }

    /// Abbreviates large counts: 1200 → "1.2k", 1200000 → "1.2m".
    private func countString(_ count: Int) -> String {
        switch count {
        case 0 ..< 1_000:   return "\(count)"
        case 1_000 ..< 1_000_000: return String(format: "%.1fk", Double(count) / 1_000)
        default:             return String(format: "%.1fm", Double(count) / 1_000_000)
        }
    }
}
