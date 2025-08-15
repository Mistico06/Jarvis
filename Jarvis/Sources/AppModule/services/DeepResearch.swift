import Foundation

actor DeepResearch {
    static let shared = DeepResearch()

    func research(query: String) async -> String? {
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
        return "Detailed research results for: \(query)"
    }
}
