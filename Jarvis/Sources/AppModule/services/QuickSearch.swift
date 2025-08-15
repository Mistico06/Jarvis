import Foundation

actor QuickSearch {
    static let shared = QuickSearch()

    func search(query: String) async -> String? {
        // Simulate API call delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        return "Search results for: \(query)"
    }
}

actor DeepResearch {
    static let shared = DeepResearch()

    func research(query: String) async -> String? {
        // Simulate deeper research delay
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        return "Detailed research results for: \(query)"
    }
}
