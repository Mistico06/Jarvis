import Foundation
import Combine

// Chat message model
struct Message: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date

    init(id: UUID = UUID(), content: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

// Shared store for all chat views
final class ConversationStore: ObservableObject {
    static let shared = ConversationStore()

    @Published private(set) var messages: [Message] = []

    private init() {}

    // MARK: – CRUD
    func addMessage(_ message: Message) {
        messages.append(message)
    }

    func clear() {
        messages.removeAll()
    }

    // SettingsView expects clearAll(); forward to clear()
    func clearAll() {
        clear()
    }
}
