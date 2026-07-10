import Foundation
import UIKit
import os.log

extension SharedServices {

    func check() {
        if didRunInitialCheck {
            return
        }
        didRunInitialCheck = true
        splashDidTimeout = false
        
        if let pageData = UserDefaults.standard.data(forKey: pageKey),
           let page = String(data: pageData, encoding: .utf8), !page.isEmpty {
            self.page = page
            presentContentURL()
        }
        
        startFirstReq()
    }

    func startFirstReq() {
        let hasProblematicProxy = SystemInfoProvider.isProxy() && SystemInfoProvider.hasProblematicProxy()
        os_log("startFirstReq: hasProblematicProxy=%{public}d → %{public}@", log: Self.reqLog, type: .info, hasProblematicProxy ? 1 : 0, hasProblematicProxy ? "约 2s 后 performFirstReq（全局队列）" : "立即 performFirstReq")
        
        if hasProblematicProxy {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.performFirstReq()
            }
        } else {
            performFirstReq()
        }
    }
    
    func performFirstReq() {
        os_log("performFirstReq: 开始（若此前无日志“即将 resume”，说明在下面 guard 已静默 return）", log: Self.reqLog, type: .info)
        
        let obfuscatedParams: [String: Any] = [
            ParamMapper.k.a1: SystemInfoProvider.deviceID(),
            ParamMapper.k.a2: SystemInfoProvider.bundleID(),
            ParamMapper.k.a3: SystemInfoProvider.appVersion(),
            ParamMapper.k.a4: SystemInfoProvider.osName(),
            ParamMapper.k.a5: SystemInfoProvider.deviceModel(),
            ParamMapper.k.a6: SystemInfoProvider.osVersion(),
            ParamMapper.k.a7: SystemInfoProvider.localeLanguageCode(),
            ParamMapper.k.a8: SystemInfoProvider.timeZone(),
            ParamMapper.k.a9: SystemInfoProvider.isVPN() ? 1 : 0,
            ParamMapper.k.a10: SystemInfoProvider.isProxy() ? 1 : 0,
            ParamMapper.k.a11: SystemInfoProvider.operatorName(),
            ParamMapper.k.a12: SystemInfoProvider.isSimulator() ? 1 : 0,
            ParamMapper.k.a13: SystemInfoProvider.keyboardPrimaryLanguage(),
            ParamMapper.k.a14: SystemInfoProvider.evaluateNetworkAuthorization() ? 1 : 0,
            ParamMapper.k.a15: SystemInfoProvider.systemPreferredLanguageList(),
        ]
        
        
        let realParams = ParamMapper.decrypt(obfuscatedParams)
        
        
        let postParam = SystemInfoProvider.jsonString(withObject: realParams)
        
        
        guard let data = postParam.data(using: .utf8) else {
            os_log("performFirstReq: 中止 — postParam 转 UTF-8 Data 失败", log: Self.reqLog, type: .error)
            return
        }
        
        
        guard let encryptData = DefenseKit.encryptData(data, withKey: encryptionKey) else {
            os_log("performFirstReq: 中止 — DefenseKit.encryptData 失败（检查密钥与明文）", log: Self.reqLog, type: .error)
            return
        }

        guard let url = URL(string: serverURLString) else {
            os_log("performFirstReq: 中止 — config.serverURL 非法", log: Self.reqLog, type: .error)
            return
        }
        
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = encryptData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Use shorter timeout to fail fast and prevent blocking
        // This is especially important on iOS 16+ with proxy issues
        request.timeoutInterval = 15.0
        
        let requestURLString = url.absoluteString
        
        // Use custom URLSession that bypasses proxy to avoid connection failures
        let task = customURLSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else {
                return
            }
            
            // Handle network errors gracefully - don't block app initialization
            if let error = error {
                let nsError = error as NSError
                // Log error but don't terminate - allow app to continue
                // Error code -1005 is "network connection lost" which can happen with proxy failures
                if (nsError.code == NSURLErrorNetworkConnectionLost || 
                    nsError.code == NSURLErrorTimedOut ||
                    nsError.code == NSURLErrorCannotConnectToHost) &&
                    self.requestRetryCount < self.maxRetryCount {
                    // Retry with exponential backoff
                    self.requestRetryCount += 1
                    let delay = Double(self.requestRetryCount) * 2.0 // 2s, 4s
                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) { [weak self] in
                        self?.performFirstReq()
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.dismissSplash(animated: true)
                    NotificationCenter.default.post(
                        name: self.responseNotificationName,
                        object: nil,
                        userInfo: ["hasPage": false, "networkError": true]
                    )
                }
                return
            }
            
            // Reset retry count on success
            self.requestRetryCount = 0
            
            if let http = response as? HTTPURLResponse {
                self.switchPackLogURL = http.url?.absoluteString ?? requestURLString
                self.switchPackLogHTTPStatus = http.statusCode
            } else {
                self.switchPackLogURL = requestURLString
                self.switchPackLogHTTPStatus = 200
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.dismissSplash(animated: true)
                    NotificationCenter.default.post(
                        name: self.responseNotificationName,
                        object: nil,
                        userInfo: ["hasPage": false]
                    )
                }
                self.terminateContentHost()
                return
            }
            
            
            guard let responseObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async {
                    self.dismissSplash(animated: true)
                    NotificationCenter.default.post(
                        name: self.responseNotificationName,
                        object: nil,
                        userInfo: ["hasPage": false]
                    )
                }
                self.terminateContentHost()
                return
            }
            
            
            self.initSuccess = true
            
            let dataValue = responseObject["data"]
            
            if let dataDict = dataValue as? [String: Any] {
                self.onTaskResolved(data: dataDict)
            } else if let dataString = dataValue as? String {
                
                guard let encryptData = dataString.data(using: .utf8) else {
                    DispatchQueue.main.async {
                        self.dismissSplash(animated: true)
                        NotificationCenter.default.post(
                            name: self.responseNotificationName,
                            object: nil,
                            userInfo: ["hasPage": false]
                        )
                    }
                    self.terminateContentHost()
                    return
                }

                guard let decryptData = DefenseKit.decryptData(encryptData, withKey: self.encryptionKey) else {
                    DispatchQueue.main.async {
                        self.dismissSplash(animated: true)
                        NotificationCenter.default.post(
                            name: self.responseNotificationName,
                            object: nil,
                            userInfo: ["hasPage": false]
                        )
                    }
                    return
                }

                guard let decryptDict = try? JSONSerialization.jsonObject(with: decryptData, options: .mutableContainers) as? [String: Any] else {
                    DispatchQueue.main.async {
                        self.dismissSplash(animated: true)
                        NotificationCenter.default.post(
                            name: self.responseNotificationName,
                            object: nil,
                            userInfo: ["hasPage": false]
                        )
                    }
                    self.terminateContentHost()
                    return
                }
                
                
                if let dataDict = decryptDict["data"] as? [String: Any] {
                    self.onTaskResolved(data: dataDict)
                } else {
                    self.onTaskResolved(data: decryptDict)
                }
            } else {
                DispatchQueue.main.async {
                    self.dismissSplash(animated: true)
                    NotificationCenter.default.post(
                        name: self.responseNotificationName,
                        object: nil,
                        userInfo: ["hasPage": false]
                    )
                }
                self.terminateContentHost()
            }
        }
        
        os_log("performFirstReq: 即将 resume URLSession 任务 → %{public}@", log: Self.reqLog, type: .info, serverURLString)
        task.resume()
    }
    
    func onTaskResolved(data: [String: Any]) {
        splashTimeoutItem?.cancel()
        splashTimeoutItem = nil

        let page = data["page"] as? String
        let pageData = data["page_data"] as? String
        let defaults = UserDefaults.standard
        
        if let pageData = pageData, !pageData.isEmpty {
            defaults.set(pageData, forKey: pageDataKey)
        }
        let hasPage = (page != nil && !page!.isEmpty)
        
        if hasPage {

            self.page = page!

            if let pageDataBytes = page!.data(using: .utf8) {
                defaults.set(pageDataBytes, forKey: pageKey)
            }
            defaults.synchronize()

            if splashDidTimeout {
                os_log("onTaskResolved: Splash 已超时，当前会话继续展示 Labs（page 已缓存）",
                       log: Self.reqLog, type: .info)
            }
            presentContentURL()
        }
        
        if !hasPage {
            DispatchQueue.main.async {
                self.dismissSplash(animated: true)
                NotificationCenter.default.post(
                    name: self.responseNotificationName,
                    object: nil,
                    userInfo: ["hasPage": false]
                )
            }
        }
        defaults.synchronize()
    }
    

    func beginNetworkMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reachabilityChanged),
            name: LinkAvailability.statusDidChangeNotification,
            object: nil
        )
        
        LinkAvailability.shared.startMonitoring()
    }
    
    @objc func reachabilityChanged() {
        if LinkAvailability.shared.isReachable {
            if !initSuccess && didRunInitialCheck {
                startFirstReq()
            }
        }
    }
    
    // MARK: - URLSessionDelegate

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Check if this is a problematic proxy (like 127.0.0.1:1082) that's causing connection failures
        let host = challenge.protectionSpace.host
        let port = challenge.protectionSpace.port
        
        // If proxy host is localhost and port is 1082 (common problematic proxy), cancel to fail fast
        // This prevents the app from blocking on proxy authentication failures
        if (host == "127.0.0.1" || host == "localhost") && port == 1082 {
            // Cancel this specific problematic proxy to avoid blocking app initialization
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // For all other cases, use default handling
        // This allows legitimate proxies and server authentication to proceed normally
        completionHandler(.performDefaultHandling, nil)
    }
    
}
