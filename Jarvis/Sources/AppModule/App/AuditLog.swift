import Foundation
import os.log

@MainActor
class AuditLog: ObservableObject {
    static let shared = AuditLog()

    private let logger = Logger(subsystem: "com.jarvis.audit", category: "log")

    private init() {}

    func logNetworkModeChange(_ mode: AppState.AppMode) {
        logger.info("Network mode changed to: \(String(describing: mode))")
    }

    func logNetworkRequest(_ purpose: String) {
        logger.info("Network request for: \(purpose)")
    }

    func clearLogs() {
        logger.info("Audit log cleared")
        // TODO: Clear persisted logs if you store them
    }

    // Optional: expose logs for UI. For now, return empty to compile.
    var networkLogs: [NetworkLog] { [] }
}

// Optional: Only include this if not defined elsewhere.
struct NetworkLog: Identifiable {
    let id = UUID()
    let host: String
    let path: String
    let method: String
    let purpose: String
    let timestamp: Date
    let isSuccess: Bool
}
