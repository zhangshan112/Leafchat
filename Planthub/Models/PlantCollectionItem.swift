import Foundation

// MARK: - PlantCollectionItem

/// A plant the user has added to their profile collection from the encyclopedia.
struct PlantCollectionItem: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let wikiPlantId: String
    let name: String
    let scientificName: String
    let imageAssetName: String?
    let addedAt: Date

    init(from wikiPlant: PlantWikiPlant) {
        id = UUID().uuidString
        wikiPlantId = wikiPlant.id
        name = wikiPlant.name
        scientificName = wikiPlant.scientificName
        imageAssetName = wikiPlant.imageName.isEmpty ? nil : wikiPlant.imageName
        addedAt = Date()
    }

    var cardData: PlantCollectionCardData {
        PlantCollectionCardData(
            id: id,
            name: name,
            coverImageAssetName: imageAssetName
        )
    }
}
