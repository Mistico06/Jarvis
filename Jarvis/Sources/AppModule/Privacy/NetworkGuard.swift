import Foundation
import Network
import os.log

@MainActor
class NetworkGuard: NSObject, ObservableObject, URLSessionDelegate {
    static let shared = NetworkGuard()

    @Published var isNetworkAllowed = false
    @Published var currentMode: NetworkMode = .offline

    private let monitor = NWPathMonitor()
    private let logger = Logger(subsystem: "com.jarvis.network", category: "guard")
    private var activeRequests: Set<String> = []

    enum NetworkMode {
        case offline
        case quickSearch
        case deepResearch
        case voiceControl
    }

    private override init() {
        super.init()
        setupNetworkMonitoring()
    }

private func setupNetworkMonitoring() {
    monitor.pathUpdateHandler = { path in
        Task {
            await MainActor.run {
                self.isNetworkAllowed = path.status == .satisfied
                let status = path.status == .satisfied ? "available" : "unavailable"
                self.logger.info("Network status: \(status)")
            }
        }
    }

    func setNetworkMode(_ mode: NetworkMode) {
        currentMode = mode
        logger.info("Network mode changed to: \(String(describing: mode))")

        switch mode {
        case .offline:
            isNetworkAllowed = false
        case .quickSearch, .deepResearch, .voiceControl:
            isNetworkAllowed = true
        }
    }

    func requestNetworkAccess(for purpose: String) -> Bool {
        guard isNetworkAllowed else {
            logger.warning("Network access denied for: \(purpose)")
            return false
        }

        activeRequests.insert(purpose)
        logger.info("Network access granted for: \(purpose)")
        return true
    }

    func releaseNetworkAccess() {
        activeRequests.removeAll()
        logger.info("Released all network access")
    }

    func releaseNetworkAccess(for purpose: String) {
        activeRequests.remove(purpose)
        logger.info("Released network access for: \(purpose)")
    }

    var hasActiveNetworkRequests: Bool {
        return !activeRequests.isEmpty
    }

    // MARK: - URLSessionDelegate

    @MainActor
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        // Extract host from the task's original request
        let host = task.originalRequest?.url?.host ?? "unknown"

        guard requestNetworkAccess(for: host) else {
            logger.warning("Network access denied for host: \(host)")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Allow the connection to proceed
        completionHandler(.performDefaultHandling, nil)
    }

    @MainActor
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            logger.error("Network request completed with error: \(error.localizedDescription)")
        }
        releaseNetworkAccess()
    }

    @MainActor
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Handle session-level authentication challenges
        completionHandler(.performDefaultHandling, nil)
    }

    // MARK: - Network Request Validation

    func validateRequest(_ request: URLRequest) -> Bool {
        guard let url = request.url else { return false }

        // Validate against allowed domains/endpoints
        let allowedHosts = [
            "api.openai.com",
            "api.anthropic.com",
            "api.together.xyz",
            "huggingface.co"
        ]

        guard let host = url.host else { return false }

        let isAllowed = allowedHosts.contains { allowedHost in
            host.hasSuffix(allowedHost)
        }

        if !isAllowed {
            logger.warning("Request to unauthorized host blocked: \(host)")
        }

        return isAllowed
    }

    // MARK: - Custom URLSession Factory

    func createSecureURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0

        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
}

// MARK: - Extensions

extension NetworkGuard.NetworkMode: CustomStringConvertible {
    var description: String {
        switch self {
        case .offline:
            return "Offline"
        case .quickSearch:
            return "Quick Search"
        case .deepResearch:
            return "Deep Research"
        case .voiceControl:
            return "Voice Control"
        }
    }
}
