import Foundation

struct KnowledgeDocument: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let size: String
    let type: String
    let url: URL?
    var isProcessing: Bool
    var isProcessed: Bool

    init(id: UUID = UUID(),
         name: String,
         size: String,
         type: String,
         url: URL? = nil,
         isProcessing: Bool = false,
         isProcessed: Bool = false) {
        self.id = id
        self.name = name
        self.size = size
        self.type = type
        self.url = url
        self.isProcessing = isProcessing
        self.isProcessed = isProcessed
    }

    var icon: String {
        switch type.lowercased() {
        case "pdf": return "doc.text.fill"
        case "txt", "md": return "doc.plaintext.fill"
        case "rtf": return "doc.richtext.fill"
        default: return "doc.fill"
        }
    }
}
