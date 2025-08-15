import Foundation
import Combine
import Metal
import os.log
import MLCSwift

@MainActor
final class ModelRuntime: ObservableObject {
    static let shared = ModelRuntime()

    // MARK: - Published State
    @Published var isLoaded = false
    @Published var currentModel: ModelSize = .lite
    @Published var loadingProgress = 0.0
    @Published var tokensPerSecond = 0.0

    // MARK: - Private Properties
    private let device: MTLDevice?
    private var engine: MLCEngine
    private let logger = Logger(subsystem: "com.jarvis.model", category: "runtime")

    // MARK: - Enums
    enum ModelSize: String {
        case lite = "lite"
        case max = "max"

        var modelPath: String {
            switch self {
            case .lite: return "qwen2.5-3b-instruct-q4_K_M"
            case .max:  return "qwen2.5-4b-instruct-q4_K_M"
            }
        }

        var modelLib: String {
            // MLCEngine expects "system://<modelLib>" in JSON; we pass raw here.
            return "mlc-llm-libs/\(self.modelPath)"
        }
    }

    enum ModelError: Error {
        case notLoaded
        case failedToLoad
        case invalidResponse
    }

    // MARK: - Initialization
    private init() {
        device = MTLCreateSystemDefaultDevice()
        engine = MLCEngine()
        if let name = device?.name {
            logger.info("Metal device initialized: \(name)")
        } else {
            logger.error("Failed to initialize Metal device")
        }
    }

    // MARK: - Model Loading
    func initializeModels() async {
        await loadModel(size: currentModel)
    }

    func switchModel(to size: ModelSize) async {
        guard size != currentModel || !isLoaded else { return }
        await loadModel(size: size)
    }

    private func loadModel(size: ModelSize) async {
        isLoaded = false
        loadingProgress = 0.0

        // MLCEngine.reload in your version is async (non-throwing)
        loadingProgress = 0.3
        await engine.reload(modelPath: size.modelPath, modelLib: size.modelLib)
        loadingProgress = 1.0
        isLoaded = true
        logger.info("Model loaded: \(size.rawValue)")
    }

    // MARK: - Chat Generation (aggregated)
    func generateText(prompt: String, maxTokens: Int) async throws -> String {
        guard isLoaded else { throw ModelError.notLoaded }

        var aggregated = ""
        let start = Date()

        let messages = [
            ChatCompletionMessage(role: .user, content: prompt)
        ]

        let stream = await engine.chat.completions.create(
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
            temperature: 0.7,
            top_p: 0.9,
            tools: nil,
            user: nil,
            response_format: nil
        )

        for await chunk in stream {
            if let delta = chunk.choices.first?.delta?.content {
                aggregated += delta
                let elapsed = Date().timeIntervalSince(start)
                let tokenCount = max(1, aggregated.count / 4) // rough estimate
                let tps = Double(tokenCount) / max(elapsed, 0.001)
                // Either of the following lines is fine; keep one:
                await MainActor.run { self.tokensPerSecond = tps }
                // or: DispatchQueue.main.async { self.tokensPerSecond = tps }
            }
        }

        return aggregated
    }

    // MARK: - Chat Generation (streaming tokens)
    func generateTextStream(
        prompt: String,
        maxTokens: Int,
        temperature: Double,
        onToken: @escaping (String) -> Void
    ) async throws {
        guard isLoaded else { throw ModelError.notLoaded }

        let start = Date()
        var producedChars = 0

        let messages = [
            ChatCompletionMessage(role: .user, content: prompt)
        ]

        let stream = await engine.chat.completions.create(
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
            top_p: 0.9,
            tools: nil,
            user: nil,
            response_format: nil
        )

        for await chunk in stream {
            if let delta = chunk.choices.first?.delta?.content, !delta.isEmpty {
                onToken(delta)
                producedChars += delta.count
                let elapsed = Date().timeIntervalSince(start)
                let approxTokens = max(1, producedChars / 4)
                let tps = Double(approxTokens) / max(elapsed, 0.001)
                // Either of the following lines is fine; keep one:
                await MainActor.run { self.tokensPerSecond = tps }
                // or: DispatchQueue.main.async { self.tokensPerSecond = tps }
            }
        }
    }
}
