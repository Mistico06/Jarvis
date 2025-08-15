import Foundation

struct KnowledgeSource: Identifiable, Equatable, Codable {
    let id: UUID
    let name: String
    let embeddingCount: Int
    var lastUpdated: Date
    var isProcessing: Bool

    init(id: UUID = UUID(), name: String, embeddingCount: Int, lastUpdated: Date, isProcessing: Bool = false) {
        self.id = id
        self.name = name
        self.embeddingCount = embeddingCount
        self.lastUpdated = lastUpdated
        self.isProcessing = isProcessing
    }

    var icon: String {
        switch name.lowercased() {
        case let n where n.contains("swift"): return "swift"
        case let n where n.contains("ios"): return "apple.logo"
        case let n where n.contains("machine"), let n where n.contains("ml"): return "brain.head.profile"
        default: return "doc.text.fill"
        }
    }
}

@MainActor
final class EmbeddingsManager: ObservableObject {
    static let shared = EmbeddingsManager()

    @Published var totalEmbeddings = 1_247
    @Published var storageSize = "15.3 MB"
    @Published var lastUpdated = Date().addingTimeInterval(-7200)
    @Published var vectorDimensions = 768
    @Published var knowledgeSources: [KnowledgeSource] = []
    @Published var isRebuilding = false
    @Published var rebuildProgress: Double = 0.0

    private init() {
        loadKnowledgeSources()
    }

    func refreshData() {
        loadKnowledgeSources()
    }

    func rebuildAllEmbeddings() {
        isRebuilding = true
        rebuildProgress = 0.0

        Task {
            for i in 0..<100 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                rebuildProgress = Double(i) / 100.0
            }
            isRebuilding = false
            rebuildProgress = 1.0
            lastUpdated = Date()
        }
    }

    func rebuildSource(_ source: KnowledgeSource) {
        guard let index = knowledgeSources.firstIndex(where: { $0.id == source.id }) else { return }
        knowledgeSources[index].isProcessing = true
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            knowledgeSources[index].isProcessing = false
            knowledgeSources[index].lastUpdated = Date()
        }
    }

    func deleteSource(_ source: KnowledgeSource) {
        knowledgeSources.removeAll { $0.id == source.id }
        totalEmbeddings -= source.embeddingCount
        updateStorageSize()
    }

    func exportEmbeddings() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("embeddings_export.json")

        let exportData: [String: Any] = [
            "total_embeddings": totalEmbeddings,
            "vector_dimensions": vectorDimensions,
            "exported_at": ISO8601DateFormatter().string(from: Date())
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            try data.write(to: fileURL)
            print("Embeddings exported to: \(fileURL)")
        } catch {
            print("Export failed: \(error)")
        }
    }

    func importEmbeddings() {
        print("Embedding import feature coming soon")
    }

    func clearAllEmbeddings() {
        totalEmbeddings = 0
        storageSize = "0 MB"
        knowledgeSources.removeAll()
        // If you have LocalEmbeddings.shared, call .clearCache() here
    }

    private func loadKnowledgeSources() {
        knowledgeSources = [
            KnowledgeSource(name: "Swift Documentation", embeddingCount: 423, lastUpdated: Date().addingTimeInterval(-3600)),
            KnowledgeSource(name: "iOS Development Guide", embeddingCount: 312, lastUpdated: Date().addingTimeInterval(-7200)),
            KnowledgeSource(name: "Machine Learning Papers", embeddingCount: 289, lastUpdated: Date().addingTimeInterval(-10800)),
            KnowledgeSource(name: "Project Notes", embeddingCount: 223, lastUpdated: Date().addingTimeInterval(-14400))
        ]
    }

    private func updateStorageSize() {
        let sizeInMB = Double(totalEmbeddings) * 0.012
        storageSize = String(format: "%.1f MB", sizeInMB)
    }
}
