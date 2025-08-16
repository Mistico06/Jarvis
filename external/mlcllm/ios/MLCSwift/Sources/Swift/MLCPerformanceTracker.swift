import Foundation

public class MLCPerformanceTracker {
    public static let shared = MLCPerformanceTracker()
    public private(set) var currentTokensPerSecond: Double = 0.0
    private var generationStart: Date?
    private var tokenCount = 0
    
    private init() {}
    
    public func startGeneration() {
        generationStart = Date()
        tokenCount = 0
    }
    
    public func recordTokenGeneration() {
        tokenCount += 1
        if let start = generationStart {
            let elapsed = Date().timeIntervalSince(start)
            currentTokensPerSecond = Double(tokenCount) / max(elapsed, 0.001)
        }
    }
}
