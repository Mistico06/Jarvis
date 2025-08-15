import Foundation

@MainActor
final class SQLHelper: ObservableObject {
    @Published var results: [String] = []
    @Published var errorMessage = ""
    @Published var isExecuting = false

    func executeQuery(_ query: String) {
        isExecuting = true
        errorMessage = ""
        results = []

        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            Task { @MainActor in
                if query.lowercased().contains("select") {
                    self.results = [
                        "id | name | email",
                        "---|------|------",
                        "1  | John | john@example.com",
                        "2  | Jane | jane@example.com",
                        "3  | Bob  | bob@example.com"
                    ]
                } else if query.lowercased().contains("create") {
                    self.results = ["Table created successfully"]
                } else if query.lowercased().contains("insert") {
                    self.results = ["1 row inserted"]
                } else {
                    self.errorMessage = "Query type not supported in demo mode"
                }
                self.isExecuting = false
            }
        }
    }

    func validateQuery(_ query: String) {
        let keywords = ["select", "from", "where", "insert", "update", "delete", "create", "drop"]
        let hasKeyword = keywords.contains { query.lowercased().contains($0) }
        errorMessage = hasKeyword ? "" : "Query must contain valid SQL keywords"
    }

    func formatQuery(_ query: String) -> String {
        return query
            .replacingOccurrences(of: " select ", with: "\nSELECT ")
            .replacingOccurrences(of: " from ", with: "\nFROM ")
            .replacingOccurrences(of: " where ", with: "\nWHERE ")
            .replacingOccurrences(of: " and ", with: "\n  AND ")
            .replacingOccurrences(of: " or ", with: "\n  OR ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
