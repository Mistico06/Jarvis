import Foundation
import Combine

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
}

// Chat message model
struct Message: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
}
