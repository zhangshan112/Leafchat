import SwiftUI

struct PlantEncyclopediaView: View {
    @Bindable private var entitlements = EntitlementStore.shared

    @State private var selectedCategoryID: String = PlantWikiModel.categories.first?.id ?? "foliage"
    @State private var searchText = ""
    @State private var showIdentification = false

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var selectedCategory: PlantWikiCategory {
        PlantWikiModel.category(by: selectedCategoryID)
    }

    private var plantsForCurrentCategory: [PlantWikiPlant] {
        PlantWikiModel.plants(in: selectedCategoryID)
    }

    private var filteredPlants: [PlantWikiPlant] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = plantsForCurrentCategory

        guard !query.isEmpty else {
            return source
        }

        return source.filter { plant in
            plant.name.localizedCaseInsensitiveContains(query)
                || plant.scientificName.localizedCaseInsensitiveContains(query)
                || plant.summary.localizedCaseInsensitiveContains(query)
                || plant.light.localizedCaseInsensitiveContains(query)
                || plant.water.localizedCaseInsensitiveContains(query)
                || plant.tags.contains(where: { $0.localizedCaseInsensitiveContains(query) })
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headerSection

                PlantCategoryTabs(
                    categories: PlantWikiModel.categories,
                    selectedCategoryID: $selectedCategoryID
                )

                CategoryIntroCard(
                    category: selectedCategory
                )

                plantsContent
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(backgroundGradient)
        .navigationTitle("Plant Encyclopedia")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showIdentification) {
            if #available(iOS 26, *) {
                PlantIdentificationView()
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Plant Encyclopedia")
                    .font(.pageTitle)
                    .foregroundStyle(Color.textPrimary)

                Text("Discover plants that fit your life")
                    .font(.captionText)
                    .foregroundStyle(Color.textSecondary)
            }

            SearchBar(
                text: $searchText,
                placeholder: "Search plants, care methods, or keywords"
            )

            if #available(iOS 26, *) {
                identifyEntryButton
            }
        }
        .padding(16)
        .background(Color.phSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primaryBlue.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.primaryBlue.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    @available(iOS 26, *)
    private var identifyEntryButton: some View {
        Button { openIdentification() } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.tagBackground)
                        .frame(width: 40, height: 40)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.primaryBlue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Identify a Plant")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text("AI")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.primaryBlue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.tagBackground)
                            .clipShape(Capsule())
                    }
                    Text("Take or upload a photo to identify any plant")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [Color.primaryBlue.opacity(0.06), Color.secondaryBlue.opacity(0.03)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primaryBlue.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var plantsContent: some View {
        if filteredPlants.isEmpty {
            EmptyStateView(
                systemImage: "tree",
                title: "No plants found.",
                description: "Try another keyword or category."
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
            .padding(.bottom, 20)
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filteredPlants) { plant in
                    NavigationLink {
                        PlantDetailView(plant: plant)
                    } label: {
                        PlantWikiCard(plant: plant)
                            .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @available(iOS 26, *)
    private func openIdentification() {
        if entitlements.aiActionAccess() == .denied {
            PaywallPresenter.shared.present(source: .identification, tab: .consumables)
        } else {
            showIdentification = true
        }
    }

    private var backgroundGradient: some View {
        ZStack(alignment: .top) {
            Color.phBackground.ignoresSafeArea()
            LinearGradient(
                colors: [
                    Color.primaryBlue.opacity(0.07),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.35)
            )
            .ignoresSafeArea()
        }
    }
}

#Preview {
    NavigationStack {
        PlantEncyclopediaView()
    }
}
