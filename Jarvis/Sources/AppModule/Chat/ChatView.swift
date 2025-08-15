import SwiftUI
import AVFoundation

// MARK: - ConversationStore Extensions
extension ConversationStore {
    // Chat-specific methods
    func addUserMessage(_ text: String) {
        let message = Message(
            id: UUID(),
            content: text,
            isUser: true,
            timestamp: Date()
        )
        addMessage(message)
    }

    func addAssistantMessage(_ text: String) {
        let message = Message(
            id: UUID(),
            content: text,
            isUser: false,
            timestamp: Date()
        )
        addMessage(message)
    }

    func addStreamingResponse(_ streamingText: String) -> Message {
        return Message(
            id: UUID(),
            content: streamingText,
            isUser: false,
            timestamp: Date()
        )
    }

    // Chat UI helpers
    var hasMessages: Bool {
        return !messages.isEmpty
    }

    var canSendMessage: Bool {
        return !messages.isEmpty || true // Always allow first message
    }
}

// MARK: - Message Extensions for Chat
extension Message {
    var displayContent: String {
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var wordCount: Int {
        return content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
}

struct ChatView: View {
    @EnvironmentObject private var modelRuntime: ModelRuntime
    @EnvironmentObject private var appState: AppState
    @StateObject private var conversationStore = ConversationStore.shared
    @StateObject private var audioEngine = AudioEngine()
    @StateObject private var imageAnalyzer = ImageAnalyzer()

    // ... rest of your ChatView code stays the same

    private func sendMessage() {
        guard !messageText.isEmpty else { return }

        // Use the extended method
        conversationStore.addUserMessage(messageText)
        let prompt = messageText
        messageText = ""

        generateResponse(for: prompt)
    }

    private func generateResponse(for prompt: String) {
        isGenerating = true
        streamingText = ""

        Task {
            do {
                let enhancedPrompt = await enhancePromptIfNeeded(prompt)

                try await modelRuntime.generateTextStream(
                    prompt: enhancedPrompt,
                    maxTokens: 512,
                    temperature: 0.7
                ) { token in
                    DispatchQueue.main.async {
                        streamingText += token
                    }
                }

                await MainActor.run {
                    // Use the extended method
                    conversationStore.addAssistantMessage(streamingText)
                    streamingText = ""
                    isGenerating = false
                }

            } catch {
                await MainActor.run {
                    conversationStore.addAssistantMessage("Sorry, I encountered an error: \(error.localizedDescription)")
                    streamingText = ""
                    isGenerating = false
                }
            }
        }
    }

    // ... rest of your code
}
