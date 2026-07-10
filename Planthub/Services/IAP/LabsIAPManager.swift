import Foundation
import Network
import StoreKit
import UIKit

public final class LabsIAPManager {

    // MARK: - Singleton

    public static let shared = LabsIAPManager()

    private init() {}

    deinit {
        transactionListener?.cancel()
        pathMonitor.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - State

    public private(set) var activeUid: String = ""

    private var transactionListener: Task<Void, Never>?
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.labsmodule.iap.path.monitor")
    private var lastPathStatus: NWPath.Status = .satisfied
    private var didBootstrap = false

    private let activeStateLock = NSLock()
    private var isLabsActivated = false

    // MARK: - Lifecycle

    public func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true

        startTransactionListener()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        startPathMonitor()
    }

    public func updateActiveUid(_ uid: String) {
        guard !uid.isEmpty else { return }
        self.activeUid = uid
    }

    public func activateLabsRoute(uid: String? = nil) {
        if let uid, !uid.isEmpty {
            updateActiveUid(uid)
        }
        activeStateLock.lock()
        let wasActive = isLabsActivated
        isLabsActivated = true
        activeStateLock.unlock()
    }

    private func isLabsRouteActive() -> Bool {
        activeStateLock.lock()
        defer { activeStateLock.unlock() }
        return isLabsActivated
    }

    @discardableResult
    public func registerPendingLabsOrder(orderid: String,
                                       productid: String,
                                       labsProductId: String? = nil,
                                       uid: String,
                                       productType: String) -> UUID {
        let token = UUID()
        let order = LabsIAPPendingOrder(
            orderid: orderid,
            productid: productid,
            labsProductId: labsProductId,
            uid: uid,
            productType: productType,
            appAccountToken: token.uuidString,
            transactionId: nil,
            awaitingFinish: false,
            createdAt: Date().timeIntervalSince1970
        )
        LabsIAPPendingStore.shared.upsert(order)
        return token
    }

    private func clearBlockingUnfinishedTransactionsForLabsProduct(productId: String) async {
        var stale: [Transaction] = []
        for await result in Transaction.unfinished {
            guard case .verified(let tx) = result, tx.productID == productId else { continue }
            if isKnownLabsTransaction(tx) {
                stale.append(tx)
            }
        }
        guard !stale.isEmpty else { return }
        for tx in stale {
            await tx.finish()
            if let o = LabsIAPPendingStore.shared.find(transactionId: String(tx.id)) {
                LabsIAPPendingStore.shared.remove(orderid: o.orderid)
            }
        }
    }

    public func purchaseForLabs(productId: String, appAccountToken: UUID?) async throws -> Transaction {
        guard SKPaymentQueue.canMakePayments() else {
            throw LabsIAPError.paymentsNotAllowed
        }
        await clearBlockingUnfinishedTransactionsForLabsProduct(productId: productId)

        let storeProducts: [Product]
        do {
            storeProducts = try await Product.products(for: [productId])
        } catch {
            throw LabsIAPError.purchaseFailed(error.localizedDescription)
        }
        guard let storeProduct = storeProducts.first else {
            throw LabsIAPError.productNotFound
        }

        var options: Set<Product.PurchaseOption> = []
        if let token = appAccountToken {
            options.insert(.appAccountToken(token))
        }

        let result: Product.PurchaseResult
        do {
            result = try await storeProduct.purchase(options: options)
        } catch {
            throw LabsIAPError.purchaseFailed(error.localizedDescription)
        }

        switch result {
        case .success(let verification):
            return try checkVerifiedLabs(verification)
        case .userCancelled:
            throw LabsIAPError.userCancelled
        case .pending:
            throw LabsIAPError.pending
        @unknown default:
            throw LabsIAPError.unknown
        }
    }

    public func findLabsOrder(orderid: String) -> LabsIAPPendingOrder? {
        LabsIAPPendingStore.shared.find(orderid: orderid)
    }

    public func findLabsOrder(transactionId: String) -> LabsIAPPendingOrder? {
        LabsIAPPendingStore.shared.find(transactionId: transactionId)
    }

    public func finishLabsOrder(orderid: String, transaction: Transaction) {
        Task {
            await transaction.finish()
            LabsIAPPendingStore.shared.remove(orderid: orderid)
        }
    }

    public func markLabsOrderAwaitingFinish(orderid: String) {
        LabsIAPPendingStore.shared.markAwaitingFinish(orderid: orderid)
    }

    public func dropLabsPendingOnCancel(orderid: String) {
        LabsIAPPendingStore.shared.remove(orderid: orderid)
    }

    public func resolveLabsPendingOrderOrClearStale(orderid: String) async -> [String: Any] {
        guard let order = LabsIAPPendingStore.shared.find(orderid: orderid) else {
            return ["status": KFIAPStatus.success.rawValue, "note": "no_pending_order"]
        }
        let tidTrim = order.transactionId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !tidTrim.isEmpty, let txNumeric = UInt64(tidTrim) else {
            markLabsOrderAwaitingFinish(orderid: orderid)
            return ["status": KFIAPStatus.success.rawValue, "note": "no_transaction_id_marked_awaiting_finish"]
        }
        for await result in Transaction.unfinished {
            guard case .verified(let tx) = result, tx.id == txNumeric else { continue }
            await tx.finish()
            LabsIAPPendingStore.shared.remove(orderid: orderid)
            return ["status": KFIAPStatus.success.rawValue, "note": "finished", "orderid": orderid]
        }
        LabsIAPPendingStore.shared.remove(orderid: orderid)
        return ["status": KFIAPStatus.success.rawValue, "note": "cleared_stale_pending", "orderid": orderid]
    }

    public func replayPendingLabsOrders(reason: String) {
        guard isLabsRouteActive() else { return }
        Task {
            let txs = await unfinishedLabsTransactions()
            await MainActor.run {
                for tx in txs { self.routeTransactionMain(tx) }
            }
        }
    }

    public func collectUnfinishedLabsTransactions() async -> [Transaction] {
        guard isLabsRouteActive() else { return [] }
        return await unfinishedLabsTransactions()
    }

    private func startTransactionListener() {
        transactionListener = Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }
                guard case .verified(let tx) = result else { continue }
                await MainActor.run { self.routeTransactionMain(tx) }
            }
        }
    }

    private func routeTransactionMain(_ transaction: Transaction) {
        guard isLabsRouteActive() else { return }

        if let token = transaction.appAccountToken,
           let order = LabsIAPPendingStore.shared.find(appAccountToken: token.uuidString) {
            handleLabsTransaction(transaction, order: order)
            return
        }

        if let order = LabsIAPPendingStore.shared.find(transactionId: String(transaction.id)) {
            handleLabsTransaction(transaction, order: order)
            return
        }
    }

    private func handleLabsTransaction(_ transaction: Transaction, order: LabsIAPPendingOrder?) {
        if let o = order, o.awaitingFinish {
            Task {
                await transaction.finish()
                LabsIAPPendingStore.shared.remove(orderid: o.orderid)
            }
            return
        }

        if let o = order, !activeUid.isEmpty, !o.uid.isEmpty, o.uid != activeUid {
            Task { await transaction.finish() }
            return
        }

        if let o = order {
            LabsIAPPendingStore.shared.updateTransactionId(orderid: o.orderid, transactionId: String(transaction.id))
        }
    }

    private func unfinishedLabsTransactions() async -> [Transaction] {
        var list: [Transaction] = []
        for await result in Transaction.unfinished {
            guard case .verified(let tx) = result else { continue }
            if isKnownLabsTransaction(tx) {
                list.append(tx)
            }
        }
        return list
    }

    private func isKnownLabsTransaction(_ transaction: Transaction) -> Bool {
        if let token = transaction.appAccountToken,
           LabsIAPPendingStore.shared.find(appAccountToken: token.uuidString) != nil {
            return true
        }
        return LabsIAPPendingStore.shared.find(transactionId: String(transaction.id)) != nil
    }

    @objc private func onWillEnterForeground() {
        replayPendingLabsOrders(reason: "willEnterForeground")
    }

    private func startPathMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let prev = self.lastPathStatus
            self.lastPathStatus = path.status
            if prev != .satisfied && path.status == .satisfied {
                DispatchQueue.main.async { self.replayPendingLabsOrders(reason: "networkRestored") }
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }

    private func checkVerifiedLabs<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw LabsIAPError.verificationFailed
        case .verified(let safe): return safe
        }
    }
}
