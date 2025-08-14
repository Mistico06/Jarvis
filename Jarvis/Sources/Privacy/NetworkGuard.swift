import Foundation
import Network
import os.log

@MainActor
class NetworkGuard: ObservableObject {
    static let shared = NetworkGuard()
    
    @Published var isNetworkBlocked = true
    @Published var currentMode: AppState.AppMode = .offline
    @Published var activeConnections: Int = 0
    
    private let logger = Logger(subsystem: "com.jarvis.privacy", category: "network")
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkGuard")
    
    private init() {
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.logger.info("Network path changed: \(path.status)")
            }
        }
        monitor.start(queue: queue)
    }
    
    func setNetworkMode(_ mode: AppState.AppMode) {
        currentMode = mode
        isNetworkBlocked = mode == .offline
        
        switch mode {
        case .offline:
            logger.info("Network access BLOCKED - Offline mode")
        case .quickSearch:
            logger.info("Network access ALLOWED - Quick search mode")
        case .deepResearch:
            logger.info("Network access ALLOWED - Deep research mode")
        }
        
        // Log mode change for audit
        AuditLog.shared.logNetworkModeChange(mode)
    }
    
    func requestNetworkAccess(for purpose: String) -> Bool {
        guard !isNetworkBlocked else {
            logger.warning("Network request DENIED for: \(purpose)")
            return false
        }
        
        logger.info("Network request ALLOWED for: \(purpose)")
        AuditLog.shared.logNetworkRequest(purpose)
        
        activeConnections += 1
        return true
    }
    
    func releaseNetworkAccess() {
        activeConnections = max(0, activeConnections - 1)
    }
    
    func blockAllNetworkAccess() {
        isNetworkBlocked = true
        currentMode = .offline
        logger.info("Emergency network block activated")
    }
}

// Custom URLSession that respects NetworkGuard
extension URLSession {
    static func jarvisSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        
        return URLSession(configuration: config, delegate: NetworkSessionDelegate(), delegateQueue: nil)
    }
}

class NetworkSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        // Check with NetworkGuard before allowing connection
        guard NetworkGuard.shared.requestNetworkAccess(for: challenge.protectionSpace.host) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        completionHandler(.performDefaultHandling, nil)
    }
}
