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
    private var engine: LLMEngine
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
            return "mlc-llm-lib/\(self.modelPath)" // ✅ FIXED interpolation
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
        engine = LLMEngine()
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

        do {
            loadingProgress = 0.2
            try await engine.reload(modelPath: size.modelPath, modelLib: size.modelLib)
            loadingProgress = 1.0
            isLoaded = true
            logger.info("Model loaded: \(size.rawValue)")
        } catch {
            isLoaded = false
            loadingProgress = 0.0
            logger.error("Model load failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Text Generation
    func generateText(prompt: String, maxTokens: Int) async throws -> String {
        guard isLoaded else {
            throw ModelError.notLoaded
        }

        let inputs = try engine.tokenize(prompt)

        let outputTokens = try await engine.generate(
            inputs: inputs,
            maxTokens: maxTokens,
            temperature: 0.7,
            topP: 0.9,
            topK: 40,
            frequencyPenalty: 0.0,
            presencePenalty: 0.0,
            progressCallback: { tokens, isComplete in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.tokensPerSecond = engine.tokensPerSecond
                }
            }
        )

        let result = try engine.detokenize(outputTokens)
        return result
    }

    func generateTextStream(
        prompt: String,
        maxTokens: Int,
        temperature: Double,
        onToken: @escaping (String) -> Void
    ) async throws {
        guard isLoaded else {
            throw ModelError.notLoaded
        }

        let inputs = try engine.tokenize(prompt)

        _ = try await engine.generate( // ✅ FIXED from \_ to _
            inputs: inputs,
            maxTokens: maxTokens,
            temperature: temperature,
            topP: 0.9,
            topK: 40,
            frequencyPenalty: 0.0,
            presencePenalty: 0.0,
            progressCallback: { tokens, isComplete in
                if let lastToken = tokens.last,
                   let chunk = try? engine.detokenize([lastToken]) {
                    onToken(chunk)
                }
                Task { @MainActor in
                    self.tokensPerSecond = engine.tokensPerSecond
                }
            }
        )
    }
}
