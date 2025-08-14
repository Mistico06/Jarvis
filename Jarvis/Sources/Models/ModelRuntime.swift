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

    enum ModelError: Error { case notLoaded }

    private init() { setupMetal() }

    private func setupMetal() {
        device = MTLCreateSystemDefaultDevice()
        guard let device = device else {
            logger.error("Failed to create Metal device")
            return
        }
        logger.info("Metal initialized: \(device.name)")
    }

    func initializeModels() async { await loadModel(size: currentModel) }

    func loadModel(size: ModelSize) async {
        guard !isModelLoaded || currentModel != size else { return }
        isModelLoaded = false
        loadingProgress = 0.0
        currentModel = size

        // Assume modelPath is valid in actual code
        // ...
        loadingProgress = 1.0
        isModelLoaded = true
        logger.info("Model loaded: \(size)")
    }

    func switchModel(to size: ModelSize) async {
        if currentModel != size || !isModelLoaded {
            await loadModel(size: size)
        }
    }

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
}
