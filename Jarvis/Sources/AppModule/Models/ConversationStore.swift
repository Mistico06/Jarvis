import Foundation
import Combine

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

final class ConversationStore: ObservableObject {
    static let shared = ConversationStore()

    @Published private(set) var messages: [Message] = []

    private init() {}

    func addMessage(_ message: Message) {
        messages.append(message)
    }

    func clear() {
        messages.removeAll()
    }

    // SettingsView calls clearAll()
    func clearAll() {
        clear()
    }
}
