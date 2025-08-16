import Foundation
import MLCSwift  // Replace with your package module name if different

@MainActor
public class ConversationManager: ObservableObject {
    @Published public var conversations: [Conversation] = []
    @Published public var activeConversation: Conversation?

    public init() {}

    // Create a new conversation seeded with a system prompt
    public func createNewConversation(systemPrompt: String = "You are a helpful AI assistant.") -> Conversation {
        let conversation = Conversation(systemPrompt: systemPrompt)
        conversations.insert(conversation, at: 0)
        activeConversation = conversation
        return conversation
    }

    // Append a message to a conversation and update its timestamp
    public func addMessage(to conversationId: UUID, role: ChatRole, content: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        let msg = ChatMessage(role: role, content: content)
        conversations[index].messages.append(msg)
        conversations[index].updatedAt = Date()
    }

    // Delete a conversation and move active selection if needed
    public func deleteConversation(_ conversationId: UUID) {
        conversations.removeAll { $0.id == conversationId }
        if activeConversation?.id == conversationId {
            activeConversation = conversations.first
        }
    }
}
