import Foundation
import Network
import os.log

@MainActor
final class NetworkGuard: NSObject, ObservableObject, URLSessionDelegate {
    static let shared = NetworkGuard()

    // Published state
    @Published var isNetworkAllowed = false
    @Published private(set) var currentMode: NetworkMode = .offline

    // Modes that govern whether network is permitted
    enum NetworkMode {
        case offline
        case quickSearch
        case deepResearch
        case voiceControl
    }

    // Internals
    private let monitor = NWPathMonitor()
    private let logger = Logger(subsystem: "com.jarvis.network", category: "guard")
    private var activeRequests: Set<String> = []

    private override init() {
        super.init()
        setupNetworkMonitoring()
    }

    // MARK: - Monitoring

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


    // MARK: - Mode handling

    /// UI provides AppState.AppMode; map it internally.
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

    /// Returns true if networking is allowed for this purpose.
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

    var hasActiveNetworkRequests: Bool { !activeRequests.isEmpty }

    // MARK: - Basic request validation

    /// Very simple allowlist. Expand to your needs.
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

    // MARK: - URLSession

    func createSecureURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    // MARK: - URLSessionDelegate (Swift 6-safe: nonisolated)

    nonisolated func urlSession(_ session: URLSession,
                                didReceive challenge: URLAuthenticationChallenge,
                                completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }

    nonisolated func urlSession(_ session: URLSession,
                                task: URLSessionTask,
                                didReceive challenge: URLAuthenticationChallenge,
                                completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }

    nonisolated func urlSession(_ session: URLSession,
                                task: URLSessionTask,
                                didCompleteWithError error: Error?) {
        if let error {
            Logger(subsystem: "com.jarvis.network", category: "guard")
                .error("Network request completed with error: \(error.localizedDescription)")
        }
        // Release access on completion
        Task { @MainActor in
            NetworkGuard.shared.releaseNetworkAccess()
        }
    }
}

// Pretty description for UI logs
extension NetworkGuard.NetworkMode: CustomStringConvertible {
    var description: String {
        switch self {
        case .offline: return "Offline"
        case .quickSearch: return "Quick Search"
        case .deepResearch: return "Deep Research"
        case .voiceControl: return "Voice Control"
        }
    }
}
