import Foundation

// MARK: - Verified transaction id cache

final class LabsIAPTransactionCache {

    static let shared = LabsIAPTransactionCache()

    private let cacheFileName = "iap_transactions.json"

    private struct CachedTransactions: Codable {
        var verifiedTransactionIds: Set<String>
        var lastUpdated: TimeInterval
    }

    private init() {}

    func isTransactionVerified(transactionId: UInt64) -> Bool {
        guard let cached = loadCache() else { return false }
        return cached.verifiedTransactionIds.contains(String(transactionId))
    }

    func markTransactionAsVerified(transactionId: UInt64) {
        var cached = loadCache() ?? CachedTransactions(
            verifiedTransactionIds: Set(),
            lastUpdated: Date().timeIntervalSince1970
        )

        cached.verifiedTransactionIds.insert(String(transactionId))
        cached.lastUpdated = Date().timeIntervalSince1970

        saveCache(cached)
    }

    func cleanupOldTransactions() {
        if let cached = loadCache() {
            let currentTime = Date().timeIntervalSince1970
            let elapsed = currentTime - cached.lastUpdated

            if elapsed > 30 * 24 * 3600 {
                clearCache()
            }
        }
    }

    func clearCache() {
        LabsFileCache.shared.delete(fileName: cacheFileName)
    }

    private func loadCache() -> CachedTransactions? {
        return LabsFileCache.shared.load(fileName: cacheFileName, as: CachedTransactions.self)
    }

    private func saveCache(_ cache: CachedTransactions) {
        LabsFileCache.shared.save(cache, fileName: cacheFileName)
    }
}

// MARK: - Pending transaction queue (file-backed)

final class LabsPendingIAPTransactionQueue {

    static let shared = LabsPendingIAPTransactionQueue()

    private let cacheFileName = "pending_iap_transactions.json"

    struct PendingTransaction: Codable {
        let transactionId: UInt64
        let productId: String
        let coins: Int
        let orderNo: String?
        let addedAt: TimeInterval
        let retryCount: Int

        init(transactionId: UInt64, productId: String, coins: Int, orderNo: String?, retryCount: Int = 0) {
            self.transactionId = transactionId
            self.productId = productId
            self.coins = coins
            self.orderNo = orderNo
            self.addedAt = Date().timeIntervalSince1970
            self.retryCount = retryCount
        }
    }

    private struct QueueData: Codable {
        var transactions: [PendingTransaction]
    }

    private init() {}

    func addTransaction(transactionId: UInt64, productId: String, coins: Int, orderNo: String?) {
        var queue = loadQueue()

        if queue.transactions.contains(where: { $0.transactionId == transactionId }) {
            return
        }

        let transaction = PendingTransaction(
            transactionId: transactionId,
            productId: productId,
            coins: coins,
            orderNo: orderNo
        )

        queue.transactions.append(transaction)
        saveQueue(queue)

    }

    func getPendingTransactions() -> [PendingTransaction] {
        let queue = loadQueue()
        return queue.transactions
    }

    func removeTransaction(transactionId: UInt64) {
        var queue = loadQueue()
        queue.transactions.removeAll { $0.transactionId == transactionId }
        saveQueue(queue)
    }

    func incrementRetryCount(transactionId: UInt64) {
        var queue = loadQueue()

        if let index = queue.transactions.firstIndex(where: { $0.transactionId == transactionId }) {
            let transaction = queue.transactions[index]
            let updatedTransaction = PendingTransaction(
                transactionId: transaction.transactionId,
                productId: transaction.productId,
                coins: transaction.coins,
                orderNo: transaction.orderNo,
                retryCount: transaction.retryCount + 1
            )
            queue.transactions[index] = updatedTransaction
            saveQueue(queue)
        }
    }

    func cleanupOldTransactions() {
        var queue = loadQueue()
        let currentTime = Date().timeIntervalSince1970
        let maxAge: TimeInterval = 7 * 24 * 3600
        let maxRetries = 10

        let originalCount = queue.transactions.count

        queue.transactions.removeAll { transaction in
            let age = currentTime - transaction.addedAt
            return age > maxAge && transaction.retryCount > maxRetries
        }

        let removedCount = originalCount - queue.transactions.count

        if removedCount > 0 {
            saveQueue(queue)
        }
    }

    func clearAll() {
        let emptyQueue = QueueData(transactions: [])
        saveQueue(emptyQueue)
    }

    private func loadQueue() -> QueueData {
        if let queue = LabsFileCache.shared.load(fileName: cacheFileName, as: QueueData.self) {
            return queue
        }
        return QueueData(transactions: [])
    }

    private func saveQueue(_ queue: QueueData) {
        LabsFileCache.shared.save(queue, fileName: cacheFileName)
    }
}

// MARK: - Pending Labs order store

final class LabsIAPPendingStore {

    private static let legacyDefaultLibrarySubdirectory = "LingoLink"

    static let shared = LabsIAPPendingStore()

    private let serialQueue = DispatchQueue(label: "com.labsmodule.iap.pending.store")
    private let fileURL: URL

    private var orders: [String: LabsIAPPendingOrder] = [:]

    private init() {
        let appName: String = {
            if let name = LabsModule.shared.config?.appName, !name.isEmpty { return name }
            return LabsIAPPendingStore.legacyDefaultLibrarySubdirectory
        }()
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent(appName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("labs_iap_pending.json")
        loadFromDisk()
    }

    func upsert(_ order: LabsIAPPendingOrder) {
        serialQueue.sync {
            orders[order.orderid] = order
            saveToDisk_locked()
        }
    }

    func updateTransactionId(orderid: String, transactionId: String) {
        serialQueue.sync {
            guard var o = orders[orderid] else { return }
            o.transactionId = transactionId
            orders[orderid] = o
            saveToDisk_locked()
        }
    }

    func markAwaitingFinish(orderid: String) {
        serialQueue.sync {
            guard var o = orders[orderid] else { return }
            o.awaitingFinish = true
            orders[orderid] = o
            saveToDisk_locked()
        }
    }

    func remove(orderid: String) {
        serialQueue.sync {
            orders.removeValue(forKey: orderid)
            saveToDisk_locked()
        }
    }

    func find(orderid: String) -> LabsIAPPendingOrder? {
        serialQueue.sync { orders[orderid] }
    }

    func find(appAccountToken: String) -> LabsIAPPendingOrder? {
        serialQueue.sync { orders.values.first { $0.appAccountToken == appAccountToken } }
    }

    func find(transactionId: String) -> LabsIAPPendingOrder? {
        serialQueue.sync { orders.values.first { $0.transactionId == transactionId } }
    }

    func all() -> [LabsIAPPendingOrder] {
        serialQueue.sync { Array(orders.values) }
    }

    private func loadFromDisk() {
        serialQueue.sync {
            guard let data = try? Data(contentsOf: fileURL),
                  let list = try? JSONDecoder().decode([LabsIAPPendingOrder].self, from: data) else {
                return
            }
            for o in list { orders[o.orderid] = o }
        }
    }

    private func saveToDisk_locked() {
        let list = Array(orders.values)
        guard let data = try? JSONEncoder().encode(list) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
