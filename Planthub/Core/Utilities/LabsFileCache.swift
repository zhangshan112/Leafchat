import Foundation

final class LabsFileCache {

    static let shared = LabsFileCache()

    private let cacheDirectory: URL

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = base.appendingPathComponent("LabsModuleCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
    }

    @discardableResult
    func save<T: Codable>(_ data: T, fileName: String) -> Bool {
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        do {
            let jsonData = try JSONEncoder().encode(data)
            try jsonData.write(to: fileURL, options: [.atomic])
            return true
        } catch {
            return false
        }
    }

    func load<T: Codable>(fileName: String, as type: T.Type) -> T? {
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let jsonData = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(type, from: jsonData)
        } catch {
            return nil
        }
    }

    @discardableResult
    func delete(fileName: String) -> Bool {
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return true }
        do {
            try FileManager.default.removeItem(at: fileURL)
            return true
        } catch {
            return false
        }
    }
}
