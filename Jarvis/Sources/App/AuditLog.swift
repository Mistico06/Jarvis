import Foundation
import os.log

@MainActor
class AuditLog: ObservableObject {
    static let shared = AuditLog()

    private let logger = Logger(subsystem: "com.jarvis.audit", category: "log")

    private init() {}

    func logNetworkModeChange(_ mode: AppState.AppMode) {
        logger.info("Network mode changed to: \(mode)")
    }

    func logNetworkRequest(_ purpose: String) {
        logger.info("Network request for: \(purpose)")
    }
}
