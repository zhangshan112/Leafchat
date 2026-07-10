import Foundation
import UIKit
import UserNotifications
import AdjustSdk

extension SharedServices {

    func adjustInit() {
        // Check if proxy is problematic before initializing Adjust SDK
        // This helps prevent low-probability startup failures on iOS 16+
        let hasProblematicProxy = SystemInfoProvider.isProxy() && SystemInfoProvider.hasProblematicProxy()
        
        // Initialize Adjust SDK in a non-blocking way with additional delay if proxy is problematic
        let delay = hasProblematicProxy ? 5.0 : 0.0
        
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            guard let rawToken = self.cfg.adjustAppToken, !rawToken.isEmpty else {
                return
            }
            let appToken = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !appToken.isEmpty else { return }
            if Self.isAdjustInitComplete(forAppToken: appToken) {
                return
            }
            let environment = AdjustBuildEnvironment.sdkEnvironment
            guard let adjustConfig = ADJConfig(appToken: appToken, environment: environment) else {
                return
            }
            
            adjustConfig.logLevel = .info
            adjustConfig.enableCostDataInAttribution()
            adjustConfig.delegate = self
            
            // Initialize Adjust SDK - it will handle its own network requests
            // If proxy fails, Adjust SDK will retry internally, but won't block app launch
            Adjust.initSdk(adjustConfig)
            Self.markAdjustInitComplete(appToken: appToken)
        }
    }
    
    func requestAPNSToken() {
        let authorizationOptions: UNAuthorizationOptions = [.badge, .sound, .alert]
        let center = UNUserNotificationCenter.current()
        
        center.getNotificationSettings { [weak self] settings in
            
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: authorizationOptions) { granted, error in
                    
                    if granted {
                        DispatchQueue.main.async {
                            self?.registerForRemoteNotifications()
                        }
                    }
                    ATTPromptCoordinator.shared.requestIfNeeded()
                }
            case .authorized:
                DispatchQueue.main.async {
                    self?.registerForRemoteNotifications()
                }
                ATTPromptCoordinator.shared.requestIfNeeded()
            case .denied:
                ATTPromptCoordinator.shared.requestIfNeeded()
            case .provisional, .ephemeral:
                ATTPromptCoordinator.shared.requestIfNeeded()
            @unknown default:
                ATTPromptCoordinator.shared.requestIfNeeded()
            }
        }
    }
        
    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        
        apnsToken = token
        let message: [String: Any] = ["token": token]
        
        if let callback = apnsCallback {
            callback(message)
            apnsCallback = nil
        }
    }
    
    func didFailToRegisterForRemoteNotifications(error: Error) {
    }
    
}
