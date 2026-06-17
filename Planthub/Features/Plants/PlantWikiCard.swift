import SwiftUI

struct PlantWikiCard: View {
    let plant: PlantWikiPlant

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            coverImage

            VStack(alignment: .leading, spacing: 8) {
                Text(plant.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(plant.scientificName)
                    .font(.smallText)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)

                difficultyBadge
                careRows
                tagsRow
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.phSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primaryBlue.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.primaryBlue.opacity(0.08), radius: 12, x: 0, y: 5)
    }

    private var coverImage: some View {
        Group {
            if !plant.imageName.isEmpty {
                Image(plant.imageName)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.surfaceViolet
                    .overlay(
                        Image(systemName: "photo.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.primaryBlue.opacity(0.35))
                    )
            }
        }
        .mediaContainer(aspectRatio: 1.0)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(8)
    }

    private var difficultyBadge: some View {
        Text(plant.difficulty.rawValue)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.primaryBlue)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.tagBackground)
            .clipShape(Capsule())
    }

    private var careRows: some View {
        VStack(alignment: .leading, spacing: 5) {
            row(icon: "sun.max.fill", title: "Light", value: plant.light)
            row(icon: "drop.fill", title: "Water", value: plant.water)
        }
    }

    private func row(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Color.primaryBlue)
                .frame(width: 14)

            Text("\(title): \(value)")
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
                .lineLimit(2)
        }
    }

    private var tagsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(plant.tags.prefix(3), id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.primaryBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.tagBackground)
                        .clipShape(Capsule())
                }
            }
            .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    PlantWikiCard(plant: PlantWikiModel.plants[0])
        .padding(16)
        .background(Color.phBackground)
}
