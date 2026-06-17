import Foundation

struct Plant: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let userId: String
    let name: String
    let species: String?
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
}

struct CreatePlantRequest: Codable, Sendable {
    let userId: String
    let name: String
    let species: String?
    let notes: String?

    init(
        userId: String,
        name: String,
        species: String? = nil,
        notes: String? = nil
    ) {
        self.userId = userId
        self.name = name
        self.species = species
        self.notes = notes
    }
}

struct PlantsResponse: Codable, Sendable {
    let data: [Plant]
}

struct PlantResponse: Codable, Sendable {
    let data: Plant
}

 struct HealthStatus: Codable, Sendable {
    let status: String
    let service: String
    let database: String
    let timestamp: Date
    let message: String?
}

struct APIErrorResponse: Codable, Sendable {
    let error: String?
    let message: String?
}
