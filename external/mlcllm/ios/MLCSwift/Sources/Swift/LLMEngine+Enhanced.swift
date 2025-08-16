//
//  LLMEngine+Enhanced.swift
//  MLCSwift
//
//  Enhancements built on top of MLCEngine's OpenAI-compatible streaming API.
//  - Simple text streaming for a single prompt
//  - Multi-turn chat streaming with completion signal
//  - Aggregated convenience wrappers
//

import Foundation

// MARK: - Role mapping between app types and engine types

private extension ChatCompletionRole {
    init(from role: ChatRole) {
        switch role {
        case .system:    self = .system
        case .user:      self = .user
        case .assistant: self = .assistant
        }
    }
}

// MARK: - Content extraction helper
// IMPORTANT: Replace the body with the exact accessors for your ChatCompletionMessageContent type.
// This fallback uses reflection to read a `text` property if present.
private func extractText(from content: ChatCompletionMessageContent) -> String? {
    // If your model defines: if case let .text(text) = content { return text }
    // Or: return content.text
    // Or: if let parts = content.parts { return parts.compactMap { if case let .text(t) = $0 { t } else { nil } }.joined() }

    let mirror = Mirror(reflecting: content)
    for child in mirror.children {
        if child.label == "text", let t = child.value as? String {
            return t.isEmpty ? nil : t
        }
        if child.label == "content", let t = child.value as? String {
            return t.isEmpty ? nil : t
        }
    }
    return nil
}

// MARK: - Convenience helpers on MLCEngine

extension MLCEngine {
    /// Stream tokens for a single-prompt completion by consuming the engine's chat stream.
    /// The caller can concatenate text deltas in the onToken closure.
    public func generateTextStream(
        prompt: String,
        maxTokens: Int,
        temperature: Double,
        topP: Double,
        onToken: @escaping (String) -> Void
    ) async {
        let messages = [
            ChatCompletionMessage(role: .user, content: prompt)
        ]

        let stream = await self.chat.completions.create(
            messages: messages,
            model: nil,
            frequency_penalty: nil,
            presence_penalty: nil,
            logprobs: false,
            top_logprobs: 0,
            logit_bias: nil,
            max_tokens: maxTokens,
            n: 1,
            seed: nil,
            stop: nil,
            stream: true,
            stream_options: StreamOptions(include_usage: false),
            temperature: Float(temperature),
            top_p: Float(topP),
            tools: nil,
            user: nil,
            response_format: nil
        )

        for await chunk in stream {
            if let choice = chunk.choices.first {
                let delta = choice.delta
                if let c = delta.content, let text = extractText(from: c), !text.isEmpty {
                    onToken(text)
                }
            }
        }
    }

    /// Stream tokens for multi-turn chat by consuming the engine's chat stream.
    /// Calls `onToken(token, false)` for text chunks and `onToken("", true)` once complete.
    public func generateChatCompletion(
        messages: [ChatMessage],
        config: GenerationConfig = GenerationConfig(),
        onToken: @escaping (String, Bool) -> Void
    ) async {
        // Map app roles to engine roles
        let mlcMessages = messages.map {
            ChatCompletionMessage(role: ChatCompletionRole(from: $0.role), content: $0.content)
        }

        let stream = await self.chat.completions.create(
            messages: mlcMessages,
            model: nil,
            frequency_penalty: Float(config.sampling.frequencyPenalty),
            presence_penalty: Float(config.sampling.presencePenalty),
            logprobs: false,
            top_logprobs: 0,
            logit_bias: nil,
            max_tokens: config.sampling.maxTokens,
            n: 1,
            seed: nil,
            stop: config.sampling.stopTokens.isEmpty ? nil : config.sampling.stopTokens,
            stream: true,
            stream_options: StreamOptions(include_usage: false),
            temperature: Float(config.sampling.temperature),
            top_p: Float(config.sampling.topP),
            tools: nil,
            user: nil,
            response_format: nil
        )

        var finished = false
        for await chunk in stream {
            if let choice = chunk.choices.first {
                let delta = choice.delta
                if let c = delta.content, let text = extractText(from: c), !text.isEmpty {
                    onToken(text, false)
                }
            }
            if chunk.usage != nil, !finished {
                finished = true
                onToken("", true)
            }
        }
        if !finished {
            onToken("", true)
        }
    }

    /// Aggregate a non-streaming result from a prompt using the streaming API.
    public func generateTextAggregated(
        prompt: String,
        maxTokens: Int,
        temperature: Double,
        topP: Double
    ) async -> String {
        var aggregated = ""
        await generateTextStream(
            prompt: prompt,
            maxTokens: maxTokens,
            temperature: temperature,
            topP: topP
        ) { delta in
            aggregated += delta
        }
        return aggregated
    }

    /// Aggregate a non-streaming result for a multi-turn chat using the streaming API.
    public func generateChatAggregated(
        messages: [ChatMessage],
        config: GenerationConfig = GenerationConfig()
    ) async -> String {
        var aggregated = ""
        await generateChatCompletion(messages: messages, config: config) { token, _ in
            aggregated += token
        }
        return aggregated
    }
}
