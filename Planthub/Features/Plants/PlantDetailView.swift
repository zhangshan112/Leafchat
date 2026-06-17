import SwiftUI

struct PlantDetailView: View {
    let plant: PlantWikiPlant

    @ObservedObject private var collectionStore = PlantCollectionStore.shared
    @ObservedObject private var session = UserSessionStore.shared

    @State private var collectScale: CGFloat = 1.0

    init(plant: PlantWikiPlant) {
        self.plant = plant
    }

    init(plantName: String) {
        self.plant = PlantWikiModel.plant(forTag: plantName)
            ?? PlantWikiModel.plant(named: plantName)
            ?? PlantWikiModel.fallbackPlant(named: plantName)
    }

    private var isCollected: Bool {
        collectionStore.isCollected(plant)
    }

    private var collectionUserId: String? {
        session.collectionUserId
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroImage
                titleSection
                collectButton
                infoGrid
                textCard(title: "Care Guide", content: plant.careGuide)
                textCard(title: "Cautions", content: plant.cautions)
                faqSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(backgroundGradient)
        .navigationTitle(plant.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCollectionIfNeeded()
        }
        .onChange(of: session.collectionUserId) { _, _ in
            loadCollectionIfNeeded()
        }
    }

    private func loadCollectionIfNeeded() {
        guard let collectionUserId else { return }
        collectionStore.load(for: collectionUserId)
    }

    private var heroImage: some View {
        Group {
            if !plant.imageName.isEmpty {
                Image(plant.imageName)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.surfaceViolet
                    .overlay(
                        Image(systemName: "photo.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Color.primaryBlue.opacity(0.35))
                    )
            }
        }
        .mediaContainer(aspectRatio: 1.2)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primaryBlue.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.primaryBlue.opacity(0.10), radius: 14, x: 0, y: 5)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(plant.name)
                .font(.pageTitle)
                .foregroundStyle(Color.textPrimary)

            Text(plant.scientificName)
                .font(.captionText)
                .foregroundStyle(Color.textSecondary)

            Text(plant.summary)
                .font(.bodyText)
                .foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                difficultyBadge
                Spacer()
                tagsRow
            }
        }
    }

    private var collectButton: some View {
        Button {
            guard let collectionUserId else { return }

            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                collectScale = 1.04
            }

            collectionStore.toggle(plant, userId: collectionUserId)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.3)) {
                    collectScale = 1.0
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isCollected ? "leaf.fill" : "leaf")
                    .font(.system(size: 16, weight: .semibold))

                Text(isCollected ? "In My Collection" : "Add to My Collection")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(isCollected ? Color.savedAmber : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background {
                if isCollected {
                    Color.savedAmber.opacity(0.14)
                } else {
                    LinearGradient(
                        colors: [Color(hex: "#8B5CF6"), Color(hex: "#7C3AED")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                if isCollected {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.savedAmber, lineWidth: 1)
                }
            }
            .shadow(
                color: isCollected ? .clear : Color.primaryBlue.opacity(0.30),
                radius: 8,
                x: 0,
                y: 4
            )
            .scaleEffect(collectScale)
        }
        .buttonStyle(.plain)
        .disabled(collectionStore.isMutating)
        .animation(.easeInOut(duration: 0.2), value: isCollected)
    }

    private var difficultyBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "staroflife.fill")
                .font(.system(size: 11))
            Text("Care Difficulty: \(plant.difficulty.rawValue)")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(Color.primaryBlue)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.tagBackground)
        .clipShape(Capsule())
    }

    private var tagsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(plant.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.primaryBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.tagBackground)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var infoGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 10
        ) {
            detailCell(icon: "sun.max.fill", title: "Light", value: plant.light)
            detailCell(icon: "drop.fill", title: "Water", value: plant.water)
            detailCell(icon: "thermometer.sun.fill", title: "Temperature", value: plant.temperature)
            detailCell(icon: "leaf.arrow.triangle.circlepath", title: "Soil", value: plant.soil)
        }
    }

    private func detailCell(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Color.primaryBlue)

            Text(value)
                .font(.captionText)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 98, alignment: .topLeading)
        .background(Color.phSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primaryBlue.opacity(0.10), lineWidth: 1)
        )
    }

    private func textCard(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.sectionTitle)
                .foregroundStyle(Color.textPrimary)

            Text(content)
                .font(.bodyText)
                .foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.phSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primaryBlue.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.primaryBlue.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Common Questions")
                .font(.sectionTitle)
                .foregroundStyle(Color.textPrimary)

            ForEach(plant.faqs) { faq in
                VStack(alignment: .leading, spacing: 6) {
                    Text("Q: \(faq.question)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    Text("A: \(faq.answer)")
                        .font(.captionText)
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.phSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primaryBlue.opacity(0.10), lineWidth: 1)
                )
            }
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
                endPoint: .init(x: 0.5, y: 0.30)
            )
            .ignoresSafeArea()
        }
    }
}
