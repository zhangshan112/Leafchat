import SwiftUI

// MARK: - View model

struct PlantCollectionCardData: Identifiable {
    let id: String
    let name: String
    let coverImageAssetName: String?
}

// MARK: - PlantCollectionCard

/// Compact plant card for the Profile collection grid.
/// 1:1 cover image (corner radius 12) + centered plant name (12pt, 1 line).
struct PlantCollectionCard: View {

    let plant: PlantCollectionCardData
    var onTap: (() -> Void)? = nil

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    cardContent
                }
                .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
    }

    // MARK: Private

    private var cardContent: some View {
        VStack(spacing: 6) {
            coverImage
            nameLabel
        }
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
                        Image(systemName: "leaf")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.textSecondary)
                    )
            }
        }
        .mediaContainer(aspectRatio: 1.0)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var nameLabel: some View {
        Text(plant.name)
            .font(.system(size: 12))
            .foregroundStyle(Color.textPrimary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
