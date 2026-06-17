import Foundation
import SwiftUI

struct PlantAPIService: Sendable {
    private let client: APIClient

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    func checkHealth() async throws -> HealthStatus {
        try await client.request(.health)
    }

    func fetchPlants(userId: String? = nil) async throws -> [Plant] {
        let response: PlantsResponse = try await client.request(.plants(userId: userId))
        return response.data
    }

    func createPlant(_ request: CreatePlantRequest) async throws -> Plant {
        let response: PlantResponse = try await client.request(.createPlant(request))
        return response.data
    }
}

private struct PlantAPIServiceKey: EnvironmentKey {
    static let defaultValue = PlantAPIService()
}

extension EnvironmentValues {
    var plantAPIService: PlantAPIService {
        get { self[PlantAPIServiceKey.self] }
        set { self[PlantAPIServiceKey.self] = newValue }
    }
}
