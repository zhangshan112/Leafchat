import SwiftUI

struct CategoryIntroCard: View {
    let category: PlantWikiCategory

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.primaryBlue)
                .frame(width: 42, height: 42)
                .background(Color.surfaceViolet)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(category.title)
                    .font(.sectionTitle)
                    .foregroundStyle(Color.textPrimary)

                Text(category.intro)
                    .font(.captionText)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.phSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primaryBlue.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.primaryBlue.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

#Preview {
    CategoryIntroCard(
        category: PlantWikiModel.categories[0]
    )
    .padding(16)
    .background(Color.phBackground)
}
