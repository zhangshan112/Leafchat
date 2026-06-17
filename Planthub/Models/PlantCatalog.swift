import Foundation

// MARK: - Plant catalog entry

/// A curated plant option used to power selectable plant pickers across the app.
/// Selecting an entry auto-fills the scientific name, suggests a garden plot,
/// and provides a bundled cover image when available in the encyclopedia.
struct PlantCatalogEntry: Identifiable, Hashable {
    let id: String
    let name: String
    let scientificName: String
    let suggestedPlot: GardenPlot
    let sampleImageAssetName: String?

    init(
        id: String,
        name: String,
        scientificName: String,
        suggestedPlot: GardenPlot,
        sampleImageAssetName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.scientificName = scientificName
        self.suggestedPlot = suggestedPlot
        self.sampleImageAssetName = sampleImageAssetName
    }
}

// MARK: - Plant catalog

enum PlantCatalog {

    static let entries: [PlantCatalogEntry] = [
        .init(id: "monstera", name: "Monstera", scientificName: "Monstera deliciosa", suggestedPlot: .newLeafWatch, sampleImageAssetName: wikiAsset("Monstera")),
        .init(id: "pothos-golden", name: "Golden Pothos", scientificName: "Epipremnum aureum", suggestedPlot: .newLeafWatch, sampleImageAssetName: wikiAsset("Golden Pothos")),
        .init(id: "pothos-marble", name: "Marble Queen Pothos", scientificName: "Epipremnum aureum", suggestedPlot: .newLeafWatch, sampleImageAssetName: wikiAsset("Golden Pothos")),
        .init(id: "snake-plant", name: "Snake Plant", scientificName: "Dracaena trifasciata", suggestedPlot: .succulentCorner),
        .init(id: "zz-plant", name: "ZZ Plant", scientificName: "Zamioculcas zamiifolia", suggestedPlot: .newLeafWatch, sampleImageAssetName: wikiAsset("ZZ Plant")),
        .init(id: "philodendron", name: "Philodendron", scientificName: "Philodendron hederaceum", suggestedPlot: .newLeafWatch, sampleImageAssetName: wikiAsset("Heartleaf Philodendron")),
        .init(id: "alocasia", name: "Alocasia Polly", scientificName: "Alocasia × amazonica", suggestedPlot: .newLeafWatch, sampleImageAssetName: wikiAsset("Alocasia Polly")),
        .init(id: "calathea", name: "Calathea Orbifolia", scientificName: "Calathea orbifolia", suggestedPlot: .yellowLeafER, sampleImageAssetName: wikiAsset("Calathea Orbifolia")),
        .init(id: "fiddle-leaf", name: "Fiddle Leaf Fig", scientificName: "Ficus lyrata", suggestedPlot: .yellowLeafER, sampleImageAssetName: wikiAsset("Fiddle Leaf Fig")),
        .init(id: "rubber-plant", name: "Rubber Plant", scientificName: "Ficus elastica", suggestedPlot: .newLeafWatch, sampleImageAssetName: wikiAsset("Baby Rubber Plant")),
        .init(id: "peace-lily", name: "Peace Lily", scientificName: "Spathiphyllum wallisii", suggestedPlot: .yellowLeafER, sampleImageAssetName: wikiAsset("Peace Lily")),
        .init(id: "echeveria", name: "Echeveria", scientificName: "Echeveria elegans", suggestedPlot: .succulentCorner, sampleImageAssetName: wikiAsset("Echeveria")),
        .init(id: "string-of-pearls", name: "String of Pearls", scientificName: "Senecio rowleyanus", suggestedPlot: .succulentCorner, sampleImageAssetName: wikiAsset("String of Pearls")),
        .init(id: "haworthia", name: "Haworthia", scientificName: "Haworthia fasciata", suggestedPlot: .succulentCorner, sampleImageAssetName: wikiAsset("Zebra Haworthia")),
        .init(id: "jade-plant", name: "Jade Plant", scientificName: "Crassula ovata", suggestedPlot: .succulentCorner, sampleImageAssetName: wikiAsset("Jade Plant")),
        .init(id: "aloe-vera", name: "Aloe Vera", scientificName: "Aloe barbadensis miller", suggestedPlot: .succulentCorner, sampleImageAssetName: wikiAsset("Aloe Vera")),
        .init(id: "cactus", name: "Cactus", scientificName: "Cactaceae", suggestedPlot: .succulentCorner, sampleImageAssetName: wikiAsset("Bunny Ear Cactus")),
        .init(id: "boston-fern", name: "Boston Fern", scientificName: "Nephrolepis exaltata", suggestedPlot: .balconyInspo, sampleImageAssetName: wikiAsset("Boston Fern")),
        .init(id: "spider-plant", name: "Spider Plant", scientificName: "Chlorophytum comosum", suggestedPlot: .balconyInspo, sampleImageAssetName: wikiAsset("Spider Plant")),
        .init(id: "basil", name: "Basil", scientificName: "Ocimum basilicum", suggestedPlot: .balconyInspo, sampleImageAssetName: wikiAsset("Sweet Basil")),
        .init(id: "rosemary", name: "Rosemary", scientificName: "Salvia rosmarinus", suggestedPlot: .balconyInspo, sampleImageAssetName: wikiAsset("Rosemary")),
        .init(id: "orchid", name: "Orchid", scientificName: "Phalaenopsis", suggestedPlot: .balconyInspo, sampleImageAssetName: wikiAsset("Phalaenopsis Orchid")),
        .init(id: "anthurium", name: "Anthurium", scientificName: "Anthurium andraeanum", suggestedPlot: .newLeafWatch, sampleImageAssetName: wikiAsset("Anthurium"))
    ]

    /// Case-insensitive lookup of a catalog entry by display name.
    static func entry(forName name: String) -> PlantCatalogEntry? {
        let query = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return entries.first { $0.name.localizedCaseInsensitiveCompare(query) == .orderedSame }
    }

    /// Filter catalog entries by a search query (matches name or scientific name).
    static func search(_ query: String) -> [PlantCatalogEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) ||
            $0.scientificName.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private static func wikiAsset(_ plantName: String) -> String? {
        guard let plant = PlantWikiModel.plant(named: plantName),
              !plant.imageName.isEmpty else { return nil }
        return plant.imageName
    }
}
