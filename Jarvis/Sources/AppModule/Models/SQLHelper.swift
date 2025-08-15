import Foundation

@MainActor
final class SQLHelper: ObservableObject {
    @Published var results: [String] = []
    @Published var errorMessage: String = ""
    @Published var isExecuting: Bool = false

    func executeQuery(_ query: String) {
        isExecuting = true
        errorMessage = ""
        results = []

        // Simulate async execution off the main thread
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            Task { @MainActor in
                let lower = query.lowercased()
                if lower.contains("select") {
                    self.results = [
                        "id | name | email",
                        "---|------|-------------------",
                        "1  | John | john@example.com",
                        "2  | Jane | jane@example.com",
                        "3  | Bob  | bob@example.com"
                    ]
                } else if lower.contains("create") {
                    self.results = ["Table created successfully"]
                } else if lower.contains("insert") {
                    self.results = ["1 row inserted"]
                } else if lower.contains("update") {
                    self.results = ["1 row updated"]
                } else if lower.contains("delete") {
                    self.results = ["1 row deleted"]
                } else {
                    self.errorMessage = "Query type not supported in demo mode"
                }
                self.isExecuting = false
            }
        }
    }

    func validateQuery(_ query: String) {
        // Very basic validation by presence of common SQL keywords
        let keywords = ["select", "from", "where", "insert", "update", "delete", "create", "drop"]
        let hasKeyword = keywords.contains { query.lowercased().contains($0) }
        errorMessage = hasKeyword ? "" : "Query must contain valid SQL keywords"
    }

    func formatQuery(_ query: String) -> String {
        // Minimal string-based formatter for demo purposes
        // Note: This is intentionally simple and not SQL-dialect-aware
        let spaced = " \(query) ".replacingOccurrences(of: "\n", with: " ")
        return spaced
            .replacingOccurrences(of: " select ", with: "\nSELECT ")
            .replacingOccurrences(of: " from ", with: "\nFROM ")
            .replacingOccurrences(of: " where ", with: "\nWHERE ")
            .replacingOccurrences(of: " group by ", with: "\nGROUP BY ")
            .replacingOccurrences(of: " order by ", with: "\nORDER BY ")
            .replacingOccurrences(of: " having ", with: "\nHAVING ")
            .replacingOccurrences(of: " and ", with: "\n  AND ")
            .replacingOccurrences(of: " or ", with: "\n  OR ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
