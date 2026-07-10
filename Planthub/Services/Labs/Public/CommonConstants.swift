import Foundation

enum LabsBridgeAction: Int {
    case probeIdentity = 1
    case beginCommerce = 2
    case settleCommerce = 3
    case syncCommerce = 4
    case openPreferences = 5
    case pageSnapshot = 6
    case dismissSurface = 7
    case bootstrapAnalytics = 8
    case trackAnalytics = 9
    case analyticsSource = 10
    case analyticsAdIdentifier = 11
    case analyticsAdvertisingId = 12
    case analyticsAuthState = 13
    case flowPreferences = 14
    case stashPayload = 15
    case recallPayload = 16
    case purgePayload = 17
    case pushCredential = 18
    case catalogLookup = 19

    static func recognizes(_ code: Int) -> Bool {
        LabsBridgeAction(rawValue: code) != nil
    }

    static let unsupportedCode = -1
}
