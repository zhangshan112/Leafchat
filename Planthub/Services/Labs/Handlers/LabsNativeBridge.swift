import Foundation
import UIKit
import WebKit
import UserNotifications
import StoreKit
import AdjustSdk

/// Unified Labs JS bridge (device / IAP / Adjust). Structural merge of former split handlers.
final class LabsNativeBridge: CoreScriptInteractor, AdjustDelegate {

    private var analyticsInvokeRef: String = ""

    override init(webView: WKWebView) {
        super.init(webView: webView)
        LabsIAPManager.shared.activateLabsRoute()
        LabsIAPManager.shared.replayPendingLabsOrders(reason: "bridgeInit")
    }

    override func supportedActions() -> [Int] {
        [
            LabsBridgeAction.probeIdentity.rawValue,
            LabsBridgeAction.openPreferences.rawValue,
            LabsBridgeAction.pageSnapshot.rawValue,
            LabsBridgeAction.dismissSurface.rawValue,
            LabsBridgeAction.flowPreferences.rawValue,
            LabsBridgeAction.stashPayload.rawValue,
            LabsBridgeAction.recallPayload.rawValue,
            LabsBridgeAction.purgePayload.rawValue,
            LabsBridgeAction.pushCredential.rawValue,
            LabsBridgeAction.beginCommerce.rawValue,
            LabsBridgeAction.settleCommerce.rawValue,
            LabsBridgeAction.syncCommerce.rawValue,
            LabsBridgeAction.catalogLookup.rawValue,
            LabsBridgeAction.bootstrapAnalytics.rawValue,
            LabsBridgeAction.trackAnalytics.rawValue,
            LabsBridgeAction.analyticsSource.rawValue,
            LabsBridgeAction.analyticsAdIdentifier.rawValue,
            LabsBridgeAction.analyticsAdvertisingId.rawValue,
            LabsBridgeAction.analyticsAuthState.rawValue
        ]
    }

    override func handleJSCall(params: [String: Any], callbackID: String) {
        guard let actionStr = params["action"] as? String,
              let actionNum = Int(actionStr),
              let action = LabsBridgeAction(rawValue: actionNum) else {
            sendError(callbackID: callbackID, message: "Invalid action")
            return
        }
        let extra = params["extra"] as? [String: Any] ?? [:]
        switch action {
        case .probeIdentity:
            fetchHardwareToken(extra: extra, callbackID: callbackID)
        case .openPreferences:
            processConfigLaunch(extra: extra, callbackID: callbackID)
        case .pageSnapshot:
            fetchCurrentContext(extra: extra, callbackID: callbackID)
        case .dismissSurface:
            dismissCurrentView()
        case .flowPreferences:
            applyFlowConfiguration(extra: extra, callbackID: callbackID)
        case .stashPayload:
            persistClientData(extra: extra, callbackID: callbackID)
        case .recallPayload:
            retrievePersistedData(extra: extra, callbackID: callbackID)
        case .purgePayload:
            processCacheEviction(extra: extra, callbackID: callbackID)
        case .pushCredential:
            processDeviceTokenRequest(extra: extra, callbackID: callbackID)
        case .beginCommerce:
            handleStartIAP(extra: extra, callbackID: callbackID)
        case .settleCommerce:
            handleFinishIAP(extra: extra, callbackID: callbackID)
        case .syncCommerce:
            handleSendAllIAPs(extra: extra, callbackID: callbackID)
        case .catalogLookup:
            handleFetchStoreProducts(extra: extra, callbackID: callbackID)
        case .bootstrapAnalytics:
            handleAdjustInit(extra: extra, callbackID: callbackID)
        case .trackAnalytics:
            handleAdjustEvent(extra: extra, callbackID: callbackID)
        case .analyticsSource:
            handleAdjustAttribution(extra: extra, callbackID: callbackID)
        case .analyticsAdIdentifier:
            handleAdjustAdId(extra: extra, callbackID: callbackID)
        case .analyticsAdvertisingId:
            handleAdjustIDFA(extra: extra, callbackID: callbackID)
        case .analyticsAuthState:
            handleAdjustAuthorizationStatus(extra: extra, callbackID: callbackID)
        }
    }

    // MARK: - Device / page / cache / push

    private func fetchHardwareToken(extra: [String: Any], callbackID: String) {
        let deviceID = SystemInfoProvider.deviceID()
        sendCallback(callbackID: callbackID, withResult: ["device_id": deviceID])
    }
    
    private func processConfigLaunch(extra: [String: Any], callbackID: String) {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
        }
    }
    
    private func fetchCurrentContext(extra: [String: Any], callbackID: String) {
        let pageDataKey = LabsModule.shared.config.userDefaultsPageDataKey
        if let pageData = UserDefaults.standard.string(forKey: pageDataKey) {
            sendCallback(callbackID: callbackID, withResult: ["page_data": pageData])
        } else {
            sendError(callbackID: callbackID, message: "Fail to get page data")
        }
    }
    
    private func dismissCurrentView() {
        SharedServices.shared.terminateContentHost()
    }
    
    private func applyFlowConfiguration(extra: [String: Any], callbackID: String) {
        SharedServices.shared.applyFlowConfiguration(navInfo: extra)
        sendCallback(callbackID: callbackID, withResult: ["status": 1])
    }
    
    private func persistClientData(extra: [String: Any], callbackID: String) {
        let defaults = UserDefaults.standard
        for (key, value) in extra {
            if let stringValue = value as? String, !stringValue.isEmpty {
                if let data = stringValue.data(using: .utf8) {
                    defaults.set(data, forKey: key)
                }
            }
        }
        defaults.synchronize()
        sendCallback(callbackID: callbackID, withResult: ["status": 1])
    }
    
    private func retrievePersistedData(extra: [String: Any], callbackID: String) {
        guard let keys = extra["keys"] as? [String] else {
            sendError(callbackID: callbackID, message: "Invalid keys")
            return
        }
        
        let defaults = UserDefaults.standard
        var values: [String: String] = [:]
        
        for key in keys {
            if let data = defaults.data(forKey: key),
               let value = String(data: data, encoding: .utf8) {
                values[key] = value
            }
        }
        
        sendCallback(callbackID: callbackID, withResult: [
            "status": 1,
            "values": values
        ])
    }
    
    private func processCacheEviction(extra: [String: Any], callbackID: String) {
        guard let keys = extra["keys"] as? [String] else {
            sendError(callbackID: callbackID, message: "Invalid keys")
            return
        }
        
        let defaults = UserDefaults.standard
        for key in keys {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
        
        sendCallback(callbackID: callbackID, withResult: ["status": 1])
    }
    
    private func processDeviceTokenRequest(extra: [String: Any], callbackID: String) {
        if let token = SharedServices.shared.apnsToken {
            sendCallback(callbackID: callbackID, withResult: [
                "status": 1,
                "token": token
            ])
            return
        }
        
        SharedServices.shared.apnsCallback = { [weak self] result in
            var finalResult = result
            finalResult["status"] = 1
            self?.sendCallback(callbackID: callbackID, withResult: finalResult)
        }
        
        SharedServices.shared.requestAPNSToken()
    }

    // MARK: - IAP

    private func handleStartIAP(extra: [String: Any], callbackID: String) {

        guard let labsProductId = stringValue(extra["productid"]), !labsProductId.isEmpty else {
            sendCallback(callbackID: callbackID, withResult: [
                "status": KFIAPStatus.failed.rawValue,
                "reason": "Missing productid"
            ])
            return
        }
        guard let orderid = stringValue(extra["orderid"]), !orderid.isEmpty else {
            sendCallback(callbackID: callbackID, withResult: [
                "status": KFIAPStatus.failed.rawValue,
                "reason": "Missing orderid",
                "productid": labsProductId
            ])
            return
        }
        let uid = stringValue(extra["uid"]) ?? ""
        let productType = stringValue(extra["product_type"]) ?? ""

        let productId: String
        #if DEBUG
        let testProductIdOverride = "cmchat_coin_1000"
        productId = testProductIdOverride
        #else
        productId = labsProductId
        #endif

        let labsProductIdForCallback: String? = (productId != labsProductId) ? labsProductId : nil

        LabsIAPManager.shared.activateLabsRoute(uid: uid)
        let token = LabsIAPManager.shared.registerPendingLabsOrder(
            orderid: orderid,
            productid: productId,
            labsProductId: labsProductIdForCallback,
            uid: uid,
            productType: productType
        )

        Task { @MainActor in
            do {
                let transaction = try await LabsIAPManager.shared.purchaseForLabs(
                    productId: productId,
                    appAccountToken: token
                )
                LabsIAPPendingStore.shared.updateTransactionId(orderid: orderid, transactionId: String(transaction.id))

                self.sendCallback(callbackID: callbackID, withResult: self.successPayload(
                    transaction: transaction,
                    order: LabsIAPManager.shared.findLabsOrder(orderid: orderid)
                ))
            } catch let error as LabsIAPError {
                if case .userCancelled = error {
                    LabsIAPManager.shared.dropLabsPendingOnCancel(orderid: orderid)
                }
                self.sendCallback(callbackID: callbackID, withResult: self.kfLabsIAPErrorResult(
                    error,
                    orderid: orderid,
                    labsProductId: labsProductId
                ))
            } catch {
                let ns = error as NSError
                self.sendCallback(callbackID: callbackID, withResult: self.kfStartIAPErrorResult(
                    status: .failed,
                    orderid: orderid,
                    labsProductId: labsProductId,
                    reason: error.localizedDescription,
                    errorCode: ns.code
                ))
            }
        }
    }

    private func handleFinishIAP(extra: [String: Any], callbackID: String) {
        let byOrder = stringValue(extra["orderid"]) ?? stringValue(extra["order_id"])
        var order: LabsIAPPendingOrder?
        if let id = byOrder, !id.isEmpty {
            order = LabsIAPManager.shared.findLabsOrder(orderid: id)
        }
        if order == nil, let txKey = stringValue(extra["transaction_id"]) {
            order = LabsIAPManager.shared.findLabsOrder(transactionId: txKey)
        }
        guard let o = order else {
            sendCallback(callbackID: callbackID, withResult: [
                "status": KFIAPStatus.success.rawValue,
                "note": "no_pending_order"
            ])
            return
        }

        Task { @MainActor in
            let res = await LabsIAPManager.shared.resolveLabsPendingOrderOrClearStale(orderid: o.orderid)
            self.sendCallback(callbackID: callbackID, withResult: res)
        }
    }

    // MARK: - Action 19: fetchStoreProducts（StoreKit localized prices）

    private func handleFetchStoreProducts(extra: [String: Any], callbackID: String) {
        let ids = Self.normalizedProductIds(from: extra)
        guard !ids.isEmpty else {
            sendCallback(callbackID: callbackID, withResult: [
                "status": 0,
                "reason": "Missing or empty keys"
            ])
            return
        }

        Task {
            var sk2Products: [Product]
            let sk2Error: String?
            do {
                sk2Products = try await Product.products(for: ids)
                sk2Error = nil
            } catch {
                sk2Products = []
                sk2Error = error.localizedDescription
            }

            let sk2BatchIds = Set(sk2Products.map(\.id))
            let missingAfterSK2Batch = ids.filter { !sk2BatchIds.contains($0) }
            if !missingAfterSK2Batch.isEmpty {
                let retriedProducts = await Self.fetchStoreKit2ProductsOneByOne(
                    ids: missingAfterSK2Batch,
                    alreadyFoundIds: sk2BatchIds
                )
                if !retriedProducts.isEmpty {
                    sk2Products.append(contentsOf: retriedProducts)
                }
            }

            let sk2Ids = Set(sk2Products.map(\.id))
            let missingAfterSK2 = ids.filter { !sk2Ids.contains($0) }

            let sk1Result: LegacyStoreKitProductFetcher.FetchResult
            if missingAfterSK2.isEmpty {
                sk1Result = .init(products: [], invalidProductIdentifiers: [], errorDescription: nil)
            } else {
                sk1Result = await LegacyStoreKitProductFetcher.fetchSKProducts(identifiers: Set(missingAfterSK2))
            }
            let sk1Products = sk1Result.products

            let currencyFallback: String? =
                sk2Products.first.flatMap { Self.currencyCodeFromProductJSON($0) }
                ?? sk1Products.first.flatMap(Self.isoCurrencyCodeFromSKProductPriceLocale)

            var mergedRows: [[String: Any]] = sk2Products.map {
                Self.serializeStoreProduct($0, storefrontCurrencyISO: currencyFallback)
            }
            mergedRows.append(contentsOf: sk1Products.map {
                Self.serializeSKProduct($0, storefrontCurrencyISO: currencyFallback)
            })

            let foundIds = Set(sk2Products.map(\.id)).union(Set(sk1Products.map(\.productIdentifier)))
            let notFound = ids.filter { !foundIds.contains($0) }

            let storefront = await Storefront.current
            var result: [String: Any] = [
                "status": 1,
                "products": mergedRows,
                "notFoundIds": notFound
            ]
            if !missingAfterSK2.isEmpty || sk2Error != nil {
                var fallbackInfo: [String: Any] = [
                    "requestedIds": missingAfterSK2,
                    "sk1ProductIds": sk1Products.map(\.productIdentifier),
                    "sk1InvalidProductIds": sk1Result.invalidProductIdentifiers
                ]
                if let sk2Error { fallbackInfo["sk2Error"] = sk2Error }
                if let e = sk1Result.errorDescription { fallbackInfo["sk1Error"] = e }
                result["storeKitFallback"] = fallbackInfo
            }
            if let meta = Self.serializeStorefrontContext(storefront: storefront, productCurrencyFallback: currencyFallback) {
                result["storefront"] = meta
            }
            await MainActor.run {
                self.sendCallback(callbackID: callbackID, withResult: result)
            }
        }
    }

    private static func serializeStoreProduct(_ p: Product, storefrontCurrencyISO: String?) -> [String: Any] {
        let jsonCurrency = currencyCodeFromProductJSON(p)
        let pricingCurrency = jsonCurrency ?? storefrontCurrencyISO
        var row: [String: Any] = [
            "id": p.id,
            "displayName": p.displayName,
            "description": p.description,
            // Apple’s default localized storefront string (signed-in App Store account storefront).
            "displayPrice": p.displayPrice,
            // Same storefront `price` value, re-formatted with the device’s current `Locale` (Settings → Language & Region).
            "localizedDisplayPriceForDevice": localizedDisplayPriceFormattedForDevice(p),
            "price": NSDecimalNumber(decimal: p.price).stringValue,
            "type": storeProductTypeString(p.type)
        ]
        if let pricingCurrency {
            row["pricingCurrencyIsoCode"] = pricingCurrency
        }
        return row
    }

    /// Some iOS 16 StoreKit 2 builds can return an empty batch when valid and invalid identifiers are mixed.
    /// Retrying one identifier at a time lets valid SKUs survive a bad test placeholder.
    private static func fetchStoreKit2ProductsOneByOne(ids: [String], alreadyFoundIds: Set<String>) async -> [Product] {
        var recovered: [Product] = []
        var seen = alreadyFoundIds
        for id in ids where !seen.contains(id) {
            do {
                let products = try await Product.products(for: [id])
                for product in products where !seen.contains(product.id) {
                    seen.insert(product.id)
                    recovered.append(product)
                }
            } catch {}
        }
        return recovered
    }

    /// Re-formats Product.price with `Locale.autoupdatingCurrent` while keeping StoreKit’s storefront currency from `priceFormatStyle`.
    private static func localizedDisplayPriceFormattedForDevice(_ p: Product) -> String {
        p.price.formatted(p.priceFormatStyle.locale(Locale.autoupdatingCurrent))
    }

    /// When StoreKit 2 returns no matching `Product` (seen on some iOS 16.x builds), fills the same payload keys via `SKProduct`.
    private static func serializeSKProduct(_ sk: SKProduct, storefrontCurrencyISO: String?) -> [String: Any] {
        let iso = iso4217Currency(from: sk.priceLocale) ?? storefrontCurrencyISO
        var row: [String: Any] = [
            "id": sk.productIdentifier,
            "displayName": sk.localizedTitle,
            "description": sk.localizedDescription,
            "displayPrice": sk1PriceFormatted(sk, formattingLocale: sk.priceLocale),
            "localizedDisplayPriceForDevice": sk1DeviceLocalizedPrice(sk),
            "price": sk.price.stringValue,
            // StoreKit 1 does not expose the same ProductType facets as StoreKit 2.
            "type": "unknown"
        ]
        if let iso {
            row["pricingCurrencyIsoCode"] = iso
        }
        return row
    }

    private static func isoCurrencyCodeFromSKProductPriceLocale(_ sk: SKProduct) -> String? {
        iso4217Currency(from: sk.priceLocale)
    }

    /// ISO 4217 from `Locale` (pricing locale from App Store Connect / storefront).
    private static func iso4217Currency(from locale: Locale) -> String? {
        guard let identifier = locale.currency?.identifier, iso4217Like(identifier) else { return nil }
        return identifier.uppercased(with: Locale(identifier: "en_US_POSIX"))
    }

    private static func sk1PriceFormatted(_ sk: SKProduct, formattingLocale: Locale) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = formattingLocale
        return f.string(from: sk.price) ?? ""
    }

    private static func sk1DeviceLocalizedPrice(_ sk: SKProduct) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale.autoupdatingCurrent
        f.currencyCode = sk.priceLocale.currency?.identifier
        return f.string(from: sk.price) ?? sk1PriceFormatted(sk, formattingLocale: sk.priceLocale)
    }

    /// `storefront.currencyIsoCode` is filled from the first product’s `jsonRepresentation` when present (same source as per-row `pricingCurrencyIsoCode`).
    private static func serializeStorefrontContext(storefront: Storefront?, productCurrencyFallback: String?) -> [String: Any]? {
        guard let storefront else { return nil }
        var o: [String: Any] = [
            "countryCode": storefront.countryCode,
            "id": storefront.id
        ]
        if let iso = productCurrencyFallback {
            o["currencyIsoCode"] = iso
        }
        o["deviceLocaleIdentifier"] = Locale.autoupdatingCurrent.identifier
        return o
    }

    /// Attempts to extract `currency` from `Product.jsonRepresentation` (App Store product JSON).
    private static func currencyCodeFromProductJSON(_ p: Product) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: p.jsonRepresentation) else { return nil }
        if let s = findCurrencyString(in: root) { return s.uppercased(with: Locale(identifier: "en_US_POSIX")) }
        return nil
    }

    /// Depth-first search for a plausible ISO 4217 `currency` field.
    private static func findCurrencyString(in json: Any, depth: Int = 0) -> String? {
        guard depth < 12 else { return nil }
        if let dict = json as? [String: Any] {
            if let c = dict["currency"] as? String, iso4217Like(c) { return c }
            if let c = dict["currencyCode"] as? String, iso4217Like(c) { return c }
            for (_, v) in dict {
                if let hit = findCurrencyString(in: v, depth: depth + 1) { return hit }
            }
            return nil
        }
        if let arr = json as? [Any] {
            for v in arr {
                if let hit = findCurrencyString(in: v, depth: depth + 1) { return hit }
            }
        }
        return nil
    }

    private static func iso4217Like(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count == 3 else { return false }
        return t.allSatisfy { $0.isLetter && $0.isASCII }
    }

    private static func storeProductTypeString(_ t: Product.ProductType) -> String {
        switch t {
        case .consumable: return "consumable"
        case .nonConsumable: return "nonConsumable"
        case .autoRenewable: return "autoRenewable"
        case .nonRenewable: return "nonRenewable"
        default: return String(describing: t)
        }
    }

    /// Accepts `keys`: `[String]`, heterogeneous JSON array, or comma-separated string. `product_ids` is kept as a transition alias.
    private static func normalizedProductIds(from extra: [String: Any]) -> [String] {
        if let raw = extra["keys"] as? [Any] {
            let parts = raw.compactMap { stringValue(any: $0) }
            return normalizeOrderPreserveFirstOccurrence(parts)
        }
        if let s = extra["keys"] as? String {
            let parts = s.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            return normalizeOrderPreserveFirstOccurrence(parts)
        }
        if let raw = extra["product_ids"] as? [Any] {
            let parts = raw.compactMap { stringValue(any: $0) }
            return normalizeOrderPreserveFirstOccurrence(parts)
        }
        if let s = extra["product_ids"] as? String {
            let parts = s.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            return normalizeOrderPreserveFirstOccurrence(parts)
        }
        return []
    }

    /// De-duplicate while keeping first occurrence order (matches common Labs SKU list UX).
    private static func normalizeOrderPreserveFirstOccurrence(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for id in ids {
            guard !seen.contains(id) else { continue }
            seen.insert(id)
            out.append(id)
        }
        return out
    }

    private static func stringValue(any: Any?) -> String? {
        if let s = any as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        if let n = any as? Int { return String(n) }
        if let n = any as? Int64 { return String(n) }
        if let n = any as? NSNumber { return n.stringValue }
        return nil
    }

    private func handleSendAllIAPs(extra: [String: Any], callbackID: String) {
        let uid = stringValue(extra["uid"])
        LabsIAPManager.shared.activateLabsRoute(uid: uid)

        Task {
            let txs = await LabsIAPManager.shared.collectUnfinishedLabsTransactions()

            let payloads: [[String: Any]] = await MainActor.run {
                txs.map { tx -> [String: Any] in
                    let order = self.lookupOrder(for: tx)
                    if let o = order {
                        LabsIAPPendingStore.shared.updateTransactionId(orderid: o.orderid, transactionId: String(tx.id))
                    }
                    return self.successPayload(transaction: tx, order: order)
                }
            }

            await MainActor.run {
                self.sendCallback(callbackID: callbackID, withResult: [
                    "status": KFIAPStatus.success.rawValue,
                    "count": payloads.count,
                    "list": payloads
                ])
            }
        }
    }

    // MARK: - Helpers

    private func lookupOrder(for transaction: Transaction) -> LabsIAPPendingOrder? {
        if let token = transaction.appAccountToken,
           let hit = LabsIAPPendingStore.shared.find(appAccountToken: token.uuidString) {
            return hit
        }
        return LabsIAPPendingStore.shared.find(transactionId: String(transaction.id))
    }

    /// - `status`              : `0` = `KFIAPStatusSuccess`
    private func successPayload(transaction: Transaction, order: LabsIAPPendingOrder?) -> [String: Any] {
        let productIdForLabs: String
        if let o = order, let labsId = o.labsProductId, !labsId.isEmpty {
            productIdForLabs = labsId
        } else {
            productIdForLabs = transaction.productID
        }
        var dict: [String: Any] = [
            "status": KFIAPStatus.success.rawValue,
            "productid": productIdForLabs,
            "transaction_id": String(transaction.id),
            "transaction_state": 1
        ]
        if let o = order {
            dict["orderid"] = o.orderid
            dict["product_type"] = o.productType
        }
        return dict
    }

    private func kfLabsIAPErrorResult(_ error: LabsIAPError, orderid: String, labsProductId: String) -> [String: Any] {
        var d: [String: Any] = [
            "status": error.kfIAPStatus.rawValue,
            "orderid": orderid,
            "productid": labsProductId,
            "reason": error.errorDescription ?? ""
        ]
        if case .userCancelled = error {
            d["errorCode"] = SKError.Code.paymentCancelled.rawValue
        }
        return d
    }

    private func kfStartIAPErrorResult(
        status: KFIAPStatus,
        orderid: String,
        labsProductId: String,
        reason: String,
        errorCode: Int? = nil
    ) -> [String: Any] {
        var d: [String: Any] = [
            "status": status.rawValue,
            "orderid": orderid,
            "productid": labsProductId,
            "reason": reason
        ]
        if let c = errorCode { d["errorCode"] = c }
        return d
    }

    private func stringValue(_ raw: Any?) -> String? {
        if let s = raw as? String { return s }
        if let n = raw as? Int { return String(n) }
        if let n = raw as? Int64 { return String(n) }
        if let n = raw as? NSNumber { return n.stringValue }
        return nil
    }

    // MARK: - Adjust

    private func handleAdjustInit(extra: [String: Any], callbackID: String) {
        
        guard let rawToken = extra["appToken"] as? String else {
            sendError(callbackID: callbackID, message: "AdjustInit Empty appToken")
            return
        }
        let appToken = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appToken.isEmpty else {
            sendError(callbackID: callbackID, message: "AdjustInit Empty appToken")
            return
        }
        
        self.analyticsInvokeRef = callbackID
        
        if SharedServices.isAdjustInitComplete(forAppToken: appToken) {
            sendCallback(callbackID: callbackID, withResult: ["status": 1])
            return
        }
        
        let environment = AdjustBuildEnvironment.sdkEnvironment
        
        guard let adjustConfig = ADJConfig(appToken: appToken, environment: environment) else {
            sendError(callbackID: callbackID, message: "Failed to create Adjust config")
            return
        }
        
        if let logLevel = extra["log_level"] as? Int {
            adjustConfig.logLevel = ADJLogLevel(rawValue: UInt(logLevel)) ?? .info
        } else {
            adjustConfig.logLevel = .info
        }
        
        
        if extra["is_SKAd"] != nil {
            adjustConfig.disableSkanAttribution()
        }
        
        if let deviceId = extra["device_id"] as? String {
            adjustConfig.externalDeviceId = deviceId
        }
        
        if let inBackground = extra["in_background"] as? Bool, inBackground {
            adjustConfig.enableSendingInBackground()
        }
        
        adjustConfig.enableCostDataInAttribution()
        
        adjustConfig.delegate = self
        
        Adjust.initSdk(adjustConfig)
        SharedServices.markAdjustInitComplete(appToken: appToken)
        sendCallback(callbackID: callbackID, withResult: ["status": 1])
    }
    
    private func handleAdjustEvent(extra: [String: Any], callbackID: String) {
        
        guard let token = extra["token"] as? String else {
            sendError(callbackID: callbackID, message: "AdjustEvent token is nil")
            return
        }
        
        guard let event = ADJEvent(eventToken: token) else {
            sendError(callbackID: callbackID, message: "AdjustEvent create failed")
            return
        }
        
        if let money = parseRevenueAmount(extra["money"]) {
            let unit = (extra["moneyUnit"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let currency = unit.isEmpty ? "USD" : unit
            event.setRevenue(money, currency: currency)
        }
        
        if let orderId = extra["orderId"] as? String {
            event.setTransactionId(orderId)
        }
        
        if let callbackParams = extra["callbackParams"] as? [String: Any] {
            for (key, value) in callbackParams {
                event.addCallbackParameter(key, value: safeString(value))
            }
        }
        
        if let partnerParams = extra["partnerParams"] as? [String: Any] {
            for (key, value) in partnerParams {
                event.addPartnerParameter(key, value: safeString(value))
            }
        }
        
        if let callbackId = extra["callbackId"] as? String {
            event.setCallbackId(callbackId)
        }
        
        Adjust.trackEvent(event)
        sendCallback(callbackID: callbackID, withResult: ["status": 1])
    }
    
    private func handleAdjustAttribution(extra: [String: Any], callbackID: String) {
        Adjust.attribution(completionHandler: { [weak self] attribution in
            var resultDict: [String: Any] = [:]
            
            if let attribution = attribution {
                resultDict["attribution"] = attribution.dictionary()
            }
            
            self?.sendCallback(callbackID: callbackID, withResult: resultDict)
        })
    }
    
    private func handleAdjustAdId(extra: [String: Any], callbackID: String) {
        Adjust.adid(completionHandler: { [weak self] adid in
            let adidString = adid ?? ""
            self?.sendCallback(callbackID: callbackID, withResult: [
                "adid": adidString
            ])
        })
    }
    
    private func handleAdjustIDFA(extra: [String: Any], callbackID: String) {
        Adjust.idfa(completionHandler: { [weak self] idfa in
            let idfaString = idfa ?? ""
            self?.sendCallback(callbackID: callbackID, withResult: ["idfa": idfaString])
        })
    }
    
    private func handleAdjustAuthorizationStatus(extra: [String: Any], callbackID: String) {
        let authStatus = Adjust.appTrackingAuthorizationStatus()
        sendCallback(callbackID: callbackID, withResult: ["status": authStatus != 0 ? 1 : 0])
    }
    
    
    func adjustAttributionChanged(_ attribution: ADJAttribution?) {
        guard !analyticsInvokeRef.isEmpty, let attribution = attribution else { return }
        
        guard let dic = attribution.dictionary() else { return }
        
        let res: [String: Any] = [
            "key": "event_attribution",
            "data": dic
        ]
        
        sendCallback(callbackID: analyticsInvokeRef, withResult: res)
    }
    
    func adjustConversionValueUpdated(_ conversionValue: NSNumber?) {
        guard let conversionValue = conversionValue else { return }
        
        let res: [String: Any] = [
            "key": "cv_update",
            "data": [
                "conversionValue": conversionValue,
                "key": "cv_update"
            ]
        ]
        
        sendCallback(callbackID: analyticsInvokeRef, withResult: res)
    }
    
    func adjustConversionValueUpdated(_ fineValue: NSNumber?, coarseValue: String?, lockWindow: NSNumber?) {
        guard let fineValue = fineValue else { return }
        
        var params: [String: Any] = [
            "fineValue": fineValue,
            "key": "adjust_cv_update"
        ]
        
        if let coarseValue = coarseValue {
            params["coarseValue"] = coarseValue
        }
        
        if let lockWindow = lockWindow {
            params["lockWindow"] = lockWindow
        }
        
        let res: [String: Any] = [
            "key": "adjust_cv_update",
            "data": params
        ]
        
        sendCallback(callbackID: analyticsInvokeRef, withResult: res)
    }
    
    private func parseRevenueAmount(_ value: Any?) -> Double? {
        guard let value = value, !(value is NSNull) else { return nil }
        if let d = value as? Double { return d }
        if let f = value as? Float { return Double(f) }
        if let i = value as? Int { return Double(i) }
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return nil }
            if let d = Double(t) { return d }
            let noCommas = t.replacingOccurrences(of: ",", with: "")
            if let d = Double(noCommas) { return d }
            if t.contains(","), !t.contains(".") {
                return Double(t.replacingOccurrences(of: ",", with: "."))
            }
            return nil
        }
        return nil
    }
    
    private func safeString(_ value: Any) -> String {
        if let string = value as? String {
            return string
        } else if let number = value as? NSNumber {
            return number.stringValue
        } else {
            return "\(value)"
        }
    }
}
