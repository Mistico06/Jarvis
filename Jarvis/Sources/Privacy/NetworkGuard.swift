import Foundation
import Network
import os.log

@MainActor
class NetworkGuard: ObservableObject {
    static let shared = NetworkGuard()
    @Published var currentMode = AppState.AppMode.offline
    @Published var isNetworkBlocked = true
    @Published var activeConnections = 0

    private let logger = Logger(subsystem: "com.jarvis.privacy", category: "network")
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkGuard")

    private init() { setupNetworkMonitoring() }

    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let statusDesc: String
                switch path.status {
                case .satisfied: statusDesc = "Satisfied"
                case .unsatisfied: statusDesc = "Unsatisfied"
                case .requiresConnection: statusDesc = "RequiresConnection"
                @unknown default: statusDesc = "Unknown"
                }
                self?.logger.info("Network path: \(statusDesc)")
            }
        }
        monitor.start(queue: queue)
    }

    func setNetworkMode(_ mode: AppState.AppMode) {
        currentMode = mode
        isNetworkBlocked = (mode == .offline)
        logger.info("Network mode changed to \(mode)")
        AuditLog.shared.logNetworkModeChange(mode)
    }

    func requestNetworkAccess(for purpose: String) -> Bool {
        guard !isNetworkBlocked else {
            logger.warning("Denied network for \(purpose)")
            return false
        }
        logger.info("Allowed network for \(purpose)")
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
        logger.info("Emergency block activated")
    }
}

extension URLSession {
    static func jarvisSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config, delegate: NetworkSessionDelegate(), delegateQueue: nil)
    }
}

class NetworkSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let host = challenge.protectionSpace.host
        guard NetworkGuard.shared.requestNetworkAccess(for: host) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.performDefaultHandling, nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        NetworkGuard.shared.releaseNetworkAccess()
    }
}
