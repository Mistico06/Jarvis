import Foundation
import MLCLLMSwift
import Combine
import Metal
import os.log

@MainActor
class ModelRuntime: ObservableObject {
    static let shared = ModelRuntime()

    @Published var isModelLoaded = false
    @Published var currentModel: ModelSize = .lite
    @Published var loadingProgress = 0.0
    @Published var tokensPerSecond = 0.0

    private var engine: MLCEngine?
    private var device: MTLDevice?
    private let logger = Logger(subsystem: "com.jarvis.model", category: "runtime")

    enum ModelSize { case lite, max }
    enum ModelError: Error { case notLoaded, failedToLoadModel }

    private init() { setupMetal() }

    private func setupMetal() {
        device = MTLCreateSystemDefaultDevice()
        guard let device = device else {
            logger.error("Failed to create Metal device")
            return
        }
        logger.info("Metal initialized: \(device.name)")
    }

    func initializeModels() async {
        await loadModel(size: currentModel)
    }

    func loadModel(size: ModelSize) async {
        if isModelLoaded && currentModel == size { return }
        isModelLoaded = false
        loadingProgress = 0.0
        currentModel = size

        // TODO: Replace with actual model loading code and valid paths
        do {
            // Example: load your model file URLs here
            let modelURL = try modelURL(for: size)

            // Initialize MLCEngine with model path
            engine = try MLCEngine(modelURL: modelURL)

            loadingProgress = 1.0
            isModelLoaded = true
            logger.info("Model loaded: \(size)")
        } catch {
            logger.error("Failed to load model: \(error.localizedDescription)")
            isModelLoaded = false
        }
    }

    func switchModel(to size: ModelSize) async {
        if currentModel != size || !isModelLoaded {
            await loadModel(size: size)
        }
    }

    // Generates full text response (non-streaming)
    func generateText(prompt: String, maxTokens: Int = 512, temperature: Float = 0.7, topP: Float = 0.9, topK: Int = 40) async throws -> String {
        guard let engine = engine, isModelLoaded else { throw ModelError.notLoaded }
        let start = CFAbsoluteTimeGetCurrent()

        let request = ChatCompletionRequest()
        request.messages = [ChatMessage(role: .user, content: prompt)]
        request.maxTokens = maxTokens
        request.temperature = temperature
        request.topP = topP
        request.topK = topK

        let response = try await engine.generateChatCompletion(request: request)

        let duration = CFAbsoluteTimeGetCurrent() - start
        if duration > 0 {
            tokensPerSecond = Double(maxTokens) / duration
        }

        return response.choices.first?.message.content ?? ""
    }

    // Streaming token generation for real-time UI update
    func generateTextStream(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7,
        topP: Float = 0.9,
        topK: Int = 40,
        onToken: @escaping (String) -> Void
    ) async throws {
        guard let engine = engine, isModelLoaded else { throw ModelError.notLoaded }

        let request = ChatCompletionRequest()
        request.messages = [ChatMessage(role: .user, content: prompt)]
        request.maxTokens = maxTokens
        request.temperature = temperature
        request.topP = topP
        request.topK = topK

        let start = CFAbsoluteTimeGetCurrent()

        // This is a stub: Replace with actual streaming call if MLCLLMSwift supports it.
        // For example, a delegate or async sequence yielding tokens.

        // Pseudo code for streaming:
        for token in try await engine.generateChatCompletionStream(request: request) {
            onToken(token)
        }

        let duration = CFAbsoluteTimeGetCurrent() - start
        if duration > 0 {
            tokensPerSecond = Double(maxTokens) / duration
        }
    }

    // Helper to get model URL by size
    private func modelURL(for size: ModelSize) throws -> URL {
        // Adjust to your actual model storage location
        let modelsBaseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        switch size {
        case .lite:
            return modelsBaseURL.appendingPathComponent("qwen2.5-3b-instruct-q4_K_M.gguf")
        case .max:
            return modelsBaseURL.appendingPathComponent("qwen2.5-4b-instruct-q4_K_M.gguf")
        }
    }
}
