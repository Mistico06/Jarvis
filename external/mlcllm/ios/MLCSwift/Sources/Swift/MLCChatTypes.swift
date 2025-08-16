import Foundation

// MARK: - Core Roles and Messages

public enum ChatRole: String, Codable, Sendable {
    case system, user, assistant
}

public struct ChatMessage: Codable, Identifiable, Sendable {
    public let id: UUID
    public let role: ChatRole
    public let content: String
    public let timestamp: Date

    public var tokenCount: Int { content.count / 4 } // Approximate

    public init(
        id: UUID = UUID(),
        role: ChatRole,
        content: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

// Convenience initializer to keep call sites terse
public extension ChatMessage {
    init(role: ChatRole, content: String) {
        self.init(id: UUID(), role: role, content: content, timestamp: Date())
    }
}

// MARK: - Conversation Model

public struct Conversation: Identifiable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var messages: [ChatMessage]
    public let createdAt: Date
    public var updatedAt: Date

    public var tokenCount: Int { messages.reduce(0) { $0 + $1.tokenCount } }
    public var lastMessage: ChatMessage? { messages.last }

    public init(
        id: UUID = UUID(),
        title: String = "New Chat",
        messages: [ChatMessage]
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    public init(systemPrompt: String) {
        self.init(messages: [ChatMessage(role: .system, content: systemPrompt)])
    }
}

// MARK: - Sampling & Generation Config

public struct SamplingParameters: Codable, Equatable, Sendable {
    public var temperature: Double
    public var topP: Double
    public var topK: Int
    public var frequencyPenalty: Double
    public var presencePenalty: Double
    public var maxTokens: Int
    public var stopTokens: [String]

    // Explicit public initializer to ensure public access to defaults
    public init(
        temperature: Double = 0.7,
        topP: Double = 0.9,
        topK: Int = 40,
        frequencyPenalty: Double = 0.0,
        presencePenalty: Double = 0.0,
        maxTokens: Int = 2048,
        stopTokens: [String] = []
    ) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.maxTokens = maxTokens
        self.stopTokens = stopTokens
    }
}

public struct GenerationConfig: Codable, Equatable, Sendable {
    public var sampling: SamplingParameters
    public var systemPrompt: String
    public var contextWindow: Int
    public var streamingEnabled: Bool

    // Explicit public initializer to make default values accessible
    public init(
        sampling: SamplingParameters = SamplingParameters(),
        systemPrompt: String = "You are a helpful AI assistant.",
        contextWindow: Int = 8192,
        streamingEnabled: Bool = true
    ) {
        self.sampling = sampling
        self.systemPrompt = systemPrompt
        self.contextWindow = contextWindow
        self.streamingEnabled = streamingEnabled
    }
}
