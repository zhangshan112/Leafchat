import Combine
import Foundation
import UIKit

// MARK: - IdentificationRecord

struct IdentificationRecord: Identifiable, Codable, Sendable {
    let id: UUID
    let commonName: String
    let scientificName: String
    let confidenceLevel: String // "high", "medium", "low"
    let careTip: String
    let thumbnailData: Data?
    let date: Date

    init(
        commonName: String,
        scientificName: String,
        confidenceLevel: String,
        careTip: String,
        thumbnail: UIImage?
    ) {
        self.id = UUID()
        self.commonName = commonName
        self.scientificName = scientificName
        self.confidenceLevel = confidenceLevel
        self.careTip = careTip
        self.date = Date()
        // Compress thumbnail to ≤100 KB for efficient UserDefaults storage
        if let img = thumbnail {
            let size = CGSize(width: 120, height: 120)
            let renderer = UIGraphicsImageRenderer(size: size)
            let resized = renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
            self.thumbnailData = resized.jpegData(compressionQuality: 0.6)
        } else {
            self.thumbnailData = nil
        }
    }

    var thumbnail: UIImage? {
        guard let data = thumbnailData else { return nil }
        return UIImage(data: data)
    }

    var confidenceColor: String {
        switch confidenceLevel {
        case "high":   return "primaryBlue"
        case "medium": return "savedAmber"
        default:       return "textSecondary"
        }
    }
}

// MARK: - IdentificationHistoryStore

@MainActor
final class IdentificationHistoryStore: ObservableObject {
    static let shared = IdentificationHistoryStore()

    @Published private(set) var records: [IdentificationRecord] = []

    private let defaultsKey = "com.planthub.identificationHistory.v1"
    private let maxRecords = 50

    private init() {
        load()
    }

    // MARK: - Public

    func add(_ record: IdentificationRecord) {
        records.insert(record, at: 0)
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }
        persist()
    }

    func remove(id: UUID) {
        records.removeAll { $0.id == id }
        persist()
    }

    func clearAll() {
        records = []
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    var recentRecords: [IdentificationRecord] {
        Array(records.prefix(10))
    }

    // MARK: - Private

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        records = (try? JSONDecoder().decode([IdentificationRecord].self, from: data)) ?? []
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
