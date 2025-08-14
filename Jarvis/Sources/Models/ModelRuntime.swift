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
    @Published var loadingProgress: Double = 0.0
    @Published var tokensPerSecond: Double = 0.0
    
    private var engine: MLCEngine?
    private var device: MTLDevice?
    private let logger = Logger(subsystem: "com.jarvis.model", category: "runtime")
    
    enum ModelSize {
        case lite, max
        
        var modelPath: String {
            switch self {
            case .lite:
                return Bundle.main.path(forResource: "qwen2.5-3b-instruct-q4_K_M", ofType: "mlc") ?? ""
            case .max:
                return Bundle.main.path(forResource: "qwen2.5-4b-instruct-q4_K_M", ofType: "mlc") ?? ""
            }
        }
        
        var contextLength: Int {
            switch self {
            case .lite: return 4096
            case .max: return 4096
            }
        }
        
        var maxTokens: Int {
            switch self {
            case .lite: return 512
            case .max: return 512
            }
        }
    }
    
    enum ModelError: Error {
        case notLoaded
    }
    
    private init() {
        setupMetal()
    }
    
    private func setupMetal() {
        device = MTLCreateSystemDefaultDevice()
        guard device != nil else {
            logger.error("Failed to create Metal device")
            return
        }
        logger.info("Metal device initialized: \(device?.name ?? "Unknown")")
    }
    
    func initializeModels() async {
        await loadModel(size: currentModel)
    }
    
    func loadModel(size: ModelSize) async {
        guard !isModelLoaded || currentModel != size else { return }
        
        isModelLoaded = false
        loadingProgress = 0.0
        currentModel = size
        
        let modelPath = size.modelPath
        guard !modelPath.isEmpty, FileManager.default.fileExists(atPath: modelPath) else {
            logger.error("Model file not found at path: \(modelPath)")
            return
        }
        
        do {
            loadingProgress = 0.3
            
            // Configure engine for A18 optimization
            let config = EngineConfig()
            config.modelPath = modelPath
            config.deviceType = .metal
            config.maxNumSequence = 1
            config.maxTotalSequenceLength = size.contextLength
            config.maxSingleSequenceLength = size.contextLength
            config.prefillChunkSize = 512 // Optimized for A18
            
            loadingProgress = 0.6
            
            engine = try MLCEngine(config: config)
            
            loadingProgress = 0.9
            
            // Test model with a simple prompt
            _ = try await generateText(
                prompt: "Hello",
                maxTokens: 5,
                temperature: 0.1
            )
            
            loadingProgress = 1.0
            isModelLoaded = true
            
            logger.info("Model loaded successfully: \(size)")
            
        } catch {
            logger.error("Failed to load model: \(error.localizedDescription)")
            isModelLoaded = false
        }
    }
    
    // Switch model dynamically
    func switchModel(to size: ModelSize) async {
        if currentModel != size || !isModelLoaded {
            await loadModel(size: size)
        }
    }
    
    func generateText(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7,
        topP: Float = 0.9,
        topK: Int = 40
    ) async throws -> String {
        guard let engine = engine, isModelLoaded else {
            throw ModelError.notLoaded
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        let request = ChatCompletionRequest()
        request.messages = [
            ChatMessage(role: .user, content: prompt)
        ]
        request.maxTokens = maxTokens
        request.temperature = temperature
        request.topP = topP
        request.topK = topK

        let response = try await engine.generateChatCompletion(request: request)

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        if duration > 0 {
            tokensPerSecond = Double(maxTokens) / duration
        }

        return response.choices.first?.message.content ?? ""
    }
}
