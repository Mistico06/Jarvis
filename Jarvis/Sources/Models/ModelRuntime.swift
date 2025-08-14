import Foundation
import Combine
import Metal
import os.log
import MLCSwift

@MainActor
final class ModelRuntime: ObservableObject {
    static let shared = ModelRuntime()

    // MARK: Published State
    @Published var isModelLoaded = false
    @Published var currentModel: ModelSize = .lite
    @Published var loadingProgress = 0.0
    @Published var tokensPerSecond = 0.0

    // MARK: Private Properties
    private var engine: MLCEngine?
    private let device: MTLDevice?
    private let logger = Logger(subsystem: "com.jarvis.model", category: "runtime")

    // MARK: Enums
    enum ModelSize {
        case lite, max
        var modelPath: String {
            switch self {
            case .lite: return "qwen2.5-3b-instruct-q4_K_M"
            case .max:  return "qwen2.5-4b-instruct-q4_K_M"
            }
        }
    }

    enum ModelError: Error {
        case notLoaded
        case failedToLoad
        case invalidResponse
    }

    // MARK: Init
    private init() {
        device = MTLCreateSystemDefaultDevice()
        if let name = device?.name {
            logger.info("Metal initialized: \(name)")
        } else {
            logger.error("Failed to create Metal device")
        }
    }

    // MARK: Public API
    func initializeModels() async {
        await loadModel(size: currentModel)
    }

    func switchModel(to size: ModelSize) async {
        guard size != currentModel || !isModelLoaded else { return }
        await loadModel(size: size)
    }

    // MARK: Load
    private func loadModel(size: ModelSize) async {
        isModelLoaded = false
        loadingProgress = 0.0
        currentModel = size

        do {
            loadingProgress = 0.3
            var cfg = EngineConfig()
            cfg.modelPath      = size.modelPath
            cfg.modelLib       = "mlc-llm-libs/\(size.modelPath)"
            cfg.deviceType     = .metal
            cfg.maxNumSequence = 1

            loadingProgress = 0.6
            engine = try MLCEngine(config: cfg)
            loadingProgress = 0.9

            // Test generation to verify model works
            _ = try await generateText(prompt: "Hello", maxTokens: 5)

            loadingProgress = 1.0
            isModelLoaded = true
            logger.info("Model loaded: \(size)")
        } catch {
            logger.error("Load failed: \(error.localizedDescription)")
            isModelLoaded = false
        }
    }

    // MARK: Inference
    func generateText(prompt: String, maxTokens: Int) async throws -> String {
        guard let eng = engine else {
            throw ModelError.notLoaded
        }

        // Tokenize prompt
        let inputs = try eng.tokenize(prompt)

        // Generate with explicit callback parameter (avoids trailing-closure ambiguity)
        let outputs = try await eng.generate(
            inputs: inputs,
            maxTokens: maxTokens,
            callback: { tokens, _ in
                Task { @MainActor in
                    self.tokensPerSecond = eng.tokensPerSecond
                }
            }
        )

        // Detokenize output
        guard let text = try? eng.detokenize(outputs) else {
            throw ModelError.invalidResponse
        }
        return text
    }
}
