import Foundation
import UIKit
import CoreTelephony
import SystemConfiguration

struct SystemInfoProvider {

    static func deviceID() -> String {
        let key = "uuid"
        let defaults = UserDefaults.standard
        
        let uuidUserDefaults = defaults.string(forKey: key)
        
        var uuid = SecureVaultAccessor.string(forKey: key)
        
        if let uuid = uuid, uuidUserDefaults == nil {
            defaults.set(uuid, forKey: key)
            defaults.synchronize()
        } 
        else if uuid == nil && uuidUserDefaults == nil {
            let uuidString = UUID().uuidString
            _ = SecureVaultAccessor.setString(uuidString, forKey: key)
            defaults.set(uuidString, forKey: key)
            defaults.synchronize()
            uuid = uuidString
        } 
        else if let uuidUserDefaults = uuidUserDefaults, let uuidValue = uuid, uuidValue != uuidUserDefaults {
            _ = SecureVaultAccessor.setString(uuidUserDefaults, forKey: key)
            uuid = uuidUserDefaults
        }
        
        return uuid ?? uuidUserDefaults ?? UUID().uuidString
    }
    
    static func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return machine
    }
    
    static func osName() -> String {
        return "apple"
    }
    
    static func osVersion() -> String {
        return UIDevice.current.systemVersion
    }
    
    static func bundleID() -> String {
        return Bundle.main.bundleIdentifier ?? ""
    }
    
    static func timeZone() -> String {
        return TimeZone.current.identifier
    }
    
    static func localeCountry() -> String {
        return Locale.current.identifier
    }
    
    static func localeLanguageCode() -> String {
        return Locale.preferredLanguages.first ?? "en"
    }

    static func keyboardPrimaryLanguage() -> String {
        let block: () -> String = {
            UITextInputMode.activeInputModes
                .compactMap { $0.primaryLanguage }
                .first { !$0.isEmpty } ?? ""
        }
        if Thread.isMainThread {
            return block()
        }
        return DispatchQueue.main.sync(execute: block)
    }

    private static let installFlagKey = "InstallFlag"
    private static let networkStateKey = "NetworkAuthorizedOnInstall"

    static func evaluateNetworkAuthorization() -> Bool {
        let defaults = UserDefaults.standard
        let hasLaunchedBefore = defaults.bool(forKey: installFlagKey)
        if !hasLaunchedBefore {
            let authorized = LinkAvailability.shared.isReachable
            defaults.set(true, forKey: installFlagKey)
            defaults.set(authorized, forKey: networkStateKey)
            defaults.synchronize()
            return authorized
        }
        return defaults.bool(forKey: networkStateKey)
    }

    static func systemPreferredLanguageList() -> [String] {
        return Locale.preferredLanguages
    }
    
    static func appVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
    
    static func isVPN() -> Bool {
        guard let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
              let scoped = proxySettings["__SCOPED__"] as? [String: Any] else {
            return false
        }
        
        for key in scoped.keys {
            if key.contains("tap") || key.contains("tun") || key.contains("ppp") {
                return true
            }
        }
        
        return false
    }
    
    static func isProxy() -> Bool {
        guard let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
              let url = URL(string: "http://www.apple.com"),
              let proxies = CFNetworkCopyProxiesForURL(url as CFURL, proxySettings as CFDictionary).takeRetainedValue() as? [[String: Any]],
              let settings = proxies.first else {
            return false
        }
        
        if let proxyType = settings[kCFProxyTypeKey as String] as? String {
            if proxyType == kCFProxyTypeNone as String {
                return false
            } else {
                return true
            }
        }
        
        return false
    }
    
    // Check if there's a problematic proxy (like 127.0.0.1:1082) that might cause connection failures
    static func hasProblematicProxy() -> Bool {
        guard let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else {
            return false
        }
        
        // Use string literals for proxy settings keys
        // Check HTTP proxy
        if let httpProxy = proxySettings["HTTPProxy"] as? String,
           let httpPort = proxySettings["HTTPPort"] as? Int {
            if (httpProxy == "127.0.0.1" || httpProxy == "localhost") && httpPort == 1082 {
                return true
            }
        }
        
        // Check HTTPS proxy
        if let httpsProxy = proxySettings["HTTPSProxy"] as? String,
           let httpsPort = proxySettings["HTTPSPort"] as? Int {
            if (httpsProxy == "127.0.0.1" || httpsProxy == "localhost") && httpsPort == 1082 {
                return true
            }
        }
        
        // Check SOCKS proxy
        if let socksProxy = proxySettings["SOCKSProxy"] as? String,
           let socksPort = proxySettings["SOCKSPort"] as? Int {
            if (socksProxy == "127.0.0.1" || socksProxy == "localhost") && socksPort == 1082 {
                return true
            }
        }
        
        // Also check for proxies in __SCOPED__ dictionary
        if let scoped = proxySettings["__SCOPED__"] as? [String: Any] {
            for (_, interfaceSettings) in scoped {
                if let interfaceDict = interfaceSettings as? [String: Any] {
                    if let httpProxy = interfaceDict["HTTPProxy"] as? String,
                       let httpPort = interfaceDict["HTTPPort"] as? Int {
                        if (httpProxy == "127.0.0.1" || httpProxy == "localhost") && httpPort == 1082 {
                            return true
                        }
                    }
                    if let httpsProxy = interfaceDict["HTTPSProxy"] as? String,
                       let httpsPort = interfaceDict["HTTPSPort"] as? Int {
                        if (httpsProxy == "127.0.0.1" || httpsProxy == "localhost") && httpsPort == 1082 {
                            return true
                        }
                    }
                }
            }
        }
        
        return false
    }
    
    static func operatorName() -> String {
        let networkInfo = CTTelephonyNetworkInfo()
        var operators: [String] = []
        
        if #available(iOS 12.0, *) {
            if let carriers = networkInfo.serviceSubscriberCellularProviders {
                for (_, carrier) in carriers {
                    let info = "\(carrier.carrierName ?? "")|\(carrier.isoCountryCode ?? "")|\(carrier.mobileNetworkCode ?? "")|\(carrier.mobileCountryCode ?? "")"
                    operators.append(info)
                }
            }
        } else {
            if let carrier = networkInfo.subscriberCellularProvider {
                let info = "\(carrier.carrierName ?? "")|\(carrier.isoCountryCode ?? "")|\(carrier.mobileNetworkCode ?? "")|\(carrier.mobileCountryCode ?? "")"
                operators.append(info)
            }
        }
        
        return operators.joined(separator: ",")
    }
    
    static func isSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    static func jsonString(withObject jsonObject: Any) -> String {
        let arguments = jsonObject is NSNull ? NSNull() : jsonObject
        let argumentsWrappedInArray = [arguments]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: argumentsWrappedInArray, options: []),
              var jsonString = String(data: jsonData, encoding: .utf8) else {
            return ""
        }
        
        if jsonString.count > 2 {
            let startIndex = jsonString.index(jsonString.startIndex, offsetBy: 1)
            let endIndex = jsonString.index(jsonString.endIndex, offsetBy: -1)
            jsonString = String(jsonString[startIndex..<endIndex])
        }
        
        return jsonString
    }
}

