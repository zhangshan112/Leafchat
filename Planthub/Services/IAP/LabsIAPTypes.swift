import Foundation

public enum KFIAPStatus: Int, Sendable {
    case success = 0
    case failed = 1
    case canceled = 2
    case notExist = 3
    case noAllow = 5
    case purchaseError = 6
}

public enum LabsIAPError: LocalizedError {
    case productNotFound
    case purchaseFailed(String)
    case verificationFailed
    case userCancelled
    case pending
    case unknown
    case paymentsNotAllowed

    public var errorDescription: String? {
        switch self {
        case .purchaseFailed(let reason): return reason
        case .productNotFound, .verificationFailed, .userCancelled, .pending, .unknown, .paymentsNotAllowed:
            return nil
        }
    }

    public var kfIAPStatus: KFIAPStatus {
        switch self {
        case .productNotFound: return .notExist
        case .purchaseFailed: return .failed
        case .verificationFailed: return .failed
        case .userCancelled: return .canceled
        case .pending: return .failed
        case .unknown: return .failed
        case .paymentsNotAllowed: return .noAllow
        }
    }
}

public struct LabsIAPPendingOrder: Codable {
    public let orderid: String
    public let productid: String
    public var labsProductId: String?
    public let uid: String
    public let productType: String
    public let appAccountToken: String
    public var transactionId: String?
    public var awaitingFinish: Bool
    public let createdAt: TimeInterval

    init(orderid: String,
         productid: String,
         labsProductId: String? = nil,
         uid: String,
         productType: String,
         appAccountToken: String,
         transactionId: String?,
         awaitingFinish: Bool,
         createdAt: TimeInterval) {
        self.orderid = orderid
        self.productid = productid
        self.labsProductId = labsProductId
        self.uid = uid
        self.productType = productType
        self.appAccountToken = appAccountToken
        self.transactionId = transactionId
        self.awaitingFinish = awaitingFinish
        self.createdAt = createdAt
    }
}
