import Combine
import Foundation

// MARK: - View state

enum PlantCollectionViewState: Equatable {
    case idle
    case loading
    case empty
    case error(String)
    case loaded
}

// MARK: - PlantCollectionStore

/// Local source of truth for plants the user collects from the encyclopedia.
@MainActor
final class PlantCollectionStore: ObservableObject {
    static let shared = PlantCollectionStore()

    @Published private(set) var items: [PlantCollectionItem] = []
    @Published private(set) var viewState: PlantCollectionViewState = .idle
    @Published private(set) var isMutating = false

    private var activeUserId: String?
    private let defaultsKey = "com.planthub.plantCollection.v1"

    private init() {}

    var count: Int { items.count }

    func contains(wikiPlantId: String) -> Bool {
        items.contains { $0.wikiPlantId == wikiPlantId }
    }

    func isCollected(_ plant: PlantWikiPlant) -> Bool {
        contains(wikiPlantId: plant.id)
    }

    /// Loads the collection for the given user from local storage.
    func load(for userId: String) {
        guard activeUserId != userId || viewState == .idle else {
            refreshViewState()
            return
        }

        activeUserId = userId
        viewState = .loading

        let stored = readSnapshot(for: userId)
        items = stored.sorted { $0.addedAt > $1.addedAt }
        refreshViewState()
    }

    func reload(for userId: String?) {
        guard let userId else {
            clearAll()
            return
        }

        load(for: userId)
    }

    func clearAll() {
        items = []
        activeUserId = nil
        viewState = .idle
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    @discardableResult
    func add(_ wikiPlant: PlantWikiPlant, userId: String) -> Bool {
        if activeUserId != userId {
            load(for: userId)
        }

        guard !contains(wikiPlantId: wikiPlant.id) else { return false }

        let item = PlantCollectionItem(from: wikiPlant)
        items.insert(item, at: 0)
        persist(for: userId)
        refreshViewState()
        return true
    }

    @discardableResult
    func remove(wikiPlantId: String, userId: String) -> Bool {
        if activeUserId != userId {
            load(for: userId)
        }

        guard let index = items.firstIndex(where: { $0.wikiPlantId == wikiPlantId }) else {
            return false
        }

        items.remove(at: index)
        persist(for: userId)
        refreshViewState()
        return true
    }

    func toggle(_ wikiPlant: PlantWikiPlant, userId: String) {
        isMutating = true
        defer { isMutating = false }

        if isCollected(wikiPlant) {
            remove(wikiPlantId: wikiPlant.id, userId: userId)
        } else {
            add(wikiPlant, userId: userId)
        }
    }

    // MARK: Private

    private func refreshViewState() {
        viewState = items.isEmpty ? .empty : .loaded
    }

    private func persist(for userId: String) {
        var snapshot = readAllSnapshots()
        snapshot[userId] = items
        writeAllSnapshots(snapshot)
    }

    private func readSnapshot(for userId: String) -> [PlantCollectionItem] {
        readAllSnapshots()[userId] ?? []
    }

    private func readAllSnapshots() -> [String: [PlantCollectionItem]] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            return [:]
        }

        return (try? JSONDecoder().decode([String: [PlantCollectionItem]].self, from: data)) ?? [:]
    }

    private func writeAllSnapshots(_ snapshot: [String: [PlantCollectionItem]]) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

// MARK: - User ID

extension UserSessionStore {
    /// Stable local key for scoping collection data to the signed-in user.
    var collectionUserId: String? {
        authUser?.id.uuidString
    }
}
