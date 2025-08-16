import Foundation

public protocol AdvancedTokenizer {
    func encode(_ text: String, addSpecialTokens: Bool) throws -> [Int]
    func decode(_ tokens: [Int], skipSpecialTokens: Bool) throws -> String
    func encodeChat(_ messages: [ChatMessage]) throws -> [Int]
    var vocabSize: Int { get }
    var specialTokens: [String: Int] { get }
}

// Example GPT-like tokenizer, basic version
public class GPTTokenizer: AdvancedTokenizer {
    public static let shared = GPTTokenizer()
    private let vocab: [String: Int]
    private let invVocab: [Int: String]
    public let specialTokens: [String: Int] = [
        "<|endoftext|>": 50256,
        "<|system|>": 50257,
        "<|user|>": 50258,
        "<|assistant|>": 50259,
        "<unk>": 0,
        "<pad>": 1
    ]
    public var vocabSize: Int { vocab.count }
    
    private init() {
        var vocab: [String: Int] = [:]
        for (i, char) in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,!?;:'\"".enumerated() {
            vocab[String(char)] = i + 10
        }
        for (tok, id) in specialTokens { vocab[tok] = id }
        self.vocab = vocab
        self.invVocab = vocab.reduce(into: [Int: String]()) { $0[$1.value] = $1.key }
    }
    
    public func encode(_ text: String, addSpecialTokens: Bool = false) throws -> [Int] {
        var tokens: [Int] = []
        if addSpecialTokens { tokens.append(specialTokens["<|endoftext|>"] ?? 0) }
        for char in text { tokens.append(vocab[String(char)] ?? (vocab["<unk>"]!)) }
        return tokens
    }
    public func decode(_ tokens: [Int], skipSpecialTokens: Bool = true) throws -> String {
        tokens.compactMap { skipSpecialTokens && specialTokens.values.contains($0) ? nil : invVocab[$0] }.joined()
    }
    public func encodeChat(_ messages: [ChatMessage]) throws -> [Int] {
        var tokens: [Int] = []
        for msg in messages {
            let prefix: Int
            switch msg.role {
            case .system:    prefix = specialTokens["<|system|>"] ?? 0
            case .user:      prefix = specialTokens["<|user|>"] ?? 0
            case .assistant: prefix = specialTokens["<|assistant|>"] ?? 0
            }
            tokens.append(prefix)
            tokens.append(contentsOf: try encode(msg.content))
            tokens.append(specialTokens["<|endoftext|>"] ?? 0)
        }
        return tokens
    }
}
