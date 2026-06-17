import SwiftUI

struct PlantCategoryTabs: View {
    let categories: [PlantWikiCategory]
    @Binding var selectedCategoryID: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories) { category in
                    categoryButton(category)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func categoryButton(_ category: PlantWikiCategory) -> some View {
        let isSelected = selectedCategoryID == category.id

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategoryID = category.id
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(category.title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .foregroundStyle(isSelected ? Color.white : Color.primaryBlue)
            .background(
                isSelected
                    ? LinearGradient(
                        colors: [Color(hex: "#8B5CF6"), Color(hex: "#7C3AED")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      )
                    : LinearGradient(
                        colors: [Color.tagBackground, Color.tagBackground],
                        startPoint: .top,
                        endPoint: .bottom
                      )
            )
            .overlay(
                Capsule()
                    .stroke(Color.primaryBlue.opacity(isSelected ? 0 : 0.20), lineWidth: 1)
            )
            .clipShape(Capsule())
            .shadow(
                color: Color.primaryBlue.opacity(isSelected ? 0.25 : 0.05),
                radius: isSelected ? 8 : 4,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var selectedID = "foliage"

    return PlantCategoryTabs(
        categories: PlantWikiModel.categories,
        selectedCategoryID: $selectedID
    )
    .padding(16)
    .background(Color.phBackground)
}
