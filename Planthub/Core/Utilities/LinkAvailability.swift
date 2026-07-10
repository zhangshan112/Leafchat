import Foundation
import SystemConfiguration

class LinkAvailability {
    static let shared = LinkAvailability()
    
    private var reachability: SCNetworkReachability?
    private let reachabilityQueue = DispatchQueue(label: "com.labs.reachability")
    
    static let statusDidChangeNotification = Notification.Name("NetworkReachabilityStatusDidChangeNotification")
    
    var isReachable: Bool {
        guard let reachability = reachability else { return false }
        
        var flags = SCNetworkReachabilityFlags()
        guard SCNetworkReachabilityGetFlags(reachability, &flags) else {
            return false
        }
        
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        let canConnectAutomatically = flags.contains(.connectionOnDemand) || flags.contains(.connectionOnTraffic)
        let canConnectWithoutUserInteraction = canConnectAutomatically && !flags.contains(.interventionRequired)
        
        return isReachable && (!needsConnection || canConnectWithoutUserInteraction)
    }
    
    private init() {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        reachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        stopMonitoring()
        
        guard let reachability = reachability else { return }
        
        let callback: SCNetworkReachabilityCallBack = { (reachabilityRef, flags, info) in
            guard let info = info else { return }
            let LinkAvailability = Unmanaged<LinkAvailability>.fromOpaque(info).takeUnretainedValue()
            LinkAvailability.reachabilityChanged(flags: flags)
        }
        
        var context = SCNetworkReachabilityContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        if SCNetworkReachabilitySetCallback(reachability, callback, &context) {
            SCNetworkReachabilitySetDispatchQueue(reachability, reachabilityQueue)
        }
    }
    
    func stopMonitoring() {
        guard let reachability = reachability else { return }
        SCNetworkReachabilitySetCallback(reachability, nil, nil)
        SCNetworkReachabilitySetDispatchQueue(reachability, nil)
    }
    
    private func reachabilityChanged(flags: SCNetworkReachabilityFlags) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: LinkAvailability.statusDidChangeNotification,
                object: self
            )
        }
    }
}

