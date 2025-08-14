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
                self?.logger.info("Network path changed: \(path.status.description)")
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
            logger.info("Network access ALLOWED - Quick Search mode")
        case .deepResearch:
            logger.info("Network access ALLOWED - Deep Research mode")
        }
        
        // Log mode change for audit
        AuditLog.shared.logNetworkModeChange(mode)
    }
    
    /// Check if network access is allowed for a specific purpose.
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
    
    /// Release a previously acquired network access.
    func releaseNetworkAccess() {
        activeConnections = max(0, activeConnections - 1)
    }
    
    /// Emergency block all network access immediately.
    func blockAllNetworkAccess() {
        isNetworkBlocked = true
        currentMode = .offline
        logger.info("Emergency network block activated")
    }
}

// Custom URLSession that respects NetworkGuard's network policies
extension URLSession {
    /// Returns a URLSession configured to respect NetworkGuard's access rules.
    static func jarvisSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        
        return URLSession(configuration: config, delegate: NetworkSessionDelegate(), delegateQueue: nil)
    }
}

/// URLSessionDelegate that checks network access with NetworkGuard before performing requests.
class NetworkSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, 
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        // Check with NetworkGuard before allowing connection
        let host = challenge.protectionSpace.host
        guard NetworkGuard.shared.requestNetworkAccess(for: host) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        completionHandler(.performDefaultHandling, nil)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Release network access count when task finishes
        NetworkGuard.shared.releaseNetworkAccess()
    }
    
    // Optional: intercept initial request to pre-check access before challenge
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        let host = task.originalRequest?.url?.host ?? "unknown"
        _ = NetworkGuard.shared.requestNetworkAccess(for: host)
    }
}
