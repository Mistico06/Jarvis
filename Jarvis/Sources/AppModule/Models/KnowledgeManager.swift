import Foundation

@MainActor
final class KnowledgeManager: ObservableObject {
    static let shared = KnowledgeManager()

    @Published var selectedDocuments: [KnowledgeDocument] = []
    @Published var isProcessing = false
    @Published var processedCount = 0

    private init() {}

    func handleDocumentSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                let doc = KnowledgeDocument(
                    name: url.lastPathComponent,
                    size: formatFileSize(url),
                    type: url.pathExtension.uppercased(),
                    url: url
                )
                selectedDocuments.append(doc)
            }
        case .failure(let error):
            print("Document selection failed: \(error)")
        }
    }

    func addScannedDocuments(_ docs: [KnowledgeDocument]) {
        selectedDocuments.append(contentsOf: docs)
    }

    func addCloudDocuments(_ docs: [KnowledgeDocument]) {
        selectedDocuments.append(contentsOf: docs)
    }

    func processDocuments() {
        isProcessing = true
        processedCount = 0

        Task {
            for (index, _) in selectedDocuments.enumerated() {
                selectedDocuments[index].isProcessing = true
                try? await Task.sleep(nanoseconds: 500_000_000) // simulate work
                selectedDocuments[index].isProcessing = false
                selectedDocuments[index].isProcessed = true
                processedCount += 1
            }
            isProcessing = false
        }
    }

    func clearSelection() {
        selectedDocuments.removeAll()
        processedCount = 0
        isProcessing = false
    }

    private func formatFileSize(_ url: URL) -> String {
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
            let fileSize = resources.fileSize ?? 0
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: Int64(fileSize))
        } catch {
            return "Unknown"
        }
    }
}
