import Foundation
import Network
import os.log

@MainActor
class NetworkGuard: NSObject, ObservableObject, URLSessionDelegate {
    static let shared = NetworkGuard()

    @Published var isNetworkAllowed = false

    enum NetworkMode {
        case offline
        case quickSearch
        case deepResearch
        case voiceControl
    }

    @Published private(set) var currentMode: NetworkMode = .offline

    private let monitor = NWPathMonitor()
    private let logger = Logger(subsystem: "com.jarvis.network", category: "guard")
    private var activeRequests: Set<String> = []

    private override init() {
        super.init()
        setupNetworkMonitoring()
    }

    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            Task { @MainActor in
                self.isNetworkAllowed = (path.status == .satisfied)
                let status = path.status == .satisfied ? "available" : "unavailable"
                self.logger.info("Network status: \(status)")
            }
        }
        let queue = DispatchQueue(label: "com.jarvis.network.monitor")
        monitor.start(queue: queue)
    }

    // UI passes AppState.AppMode. We map internally.
    func setNetworkMode(_ mode: AppState.AppMode) {
        let mapped: NetworkMode
        switch mode {
        case .offline:      mapped = .offline
        case .quickSearch:  mapped = .quickSearch
        case .deepResearch: mapped = .deepResearch
        case .voiceControl: mapped = .voiceControl
        }

        currentMode = mapped
        logger.info("Network mode changed to: \(String(describing: mapped))")

        switch mapped {
        case .offline:
            isNetworkAllowed = false
        case .quickSearch, .deepResearch, .voiceControl:
            isNetworkAllowed = true
        }
    }

    // MARK: - Request gating

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

    // MARK: - URLSessionDelegate (signatures aligned with SDK)

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let host = task.originalRequest?.url?.host ?? "unknown"
        guard requestNetworkAccess(for: host) else {
            logger.warning("Network access denied for host: \(host)")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.performDefaultHandling, nil)
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: (any Error)?) {
        if let error = error {
            logger.error("Network request completed with error: \(error.localizedDescription)")
        }
        releaseNetworkAccess()
    }

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Session-level challenges (e.g., TLS)
        completionHandler(.performDefaultHandling, nil)
    }

    // MARK: - Request validation

    func validateRequest(_ request: URLRequest) -> Bool {
        guard let url = request.url, let host = url.host else { return false }

        let allowedHosts = [
            "api.openai.com",
            "api.anthropic.com",
            "api.together.xyz",
            "huggingface.co"
        ]

        let isAllowed = allowedHosts.contains { host.hasSuffix($0) }
        if !isAllowed {
            logger.warning("Request to unauthorized host blocked: \(host)")
        }
        return isAllowed
    }

    // MARK: - URLSession factory

    func createSecureURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
}

// MARK: - Pretty description

extension NetworkGuard.NetworkMode: CustomStringConvertible {
    var description: String {
        switch self {
        case .offline:      return "Offline"
        case .quickSearch:  return "Quick Search"
        case .deepResearch: return "Deep Research"
        case .voiceControl: return "Voice Control"
        }
    }
}
