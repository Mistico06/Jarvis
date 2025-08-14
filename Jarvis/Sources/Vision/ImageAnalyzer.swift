import Foundation
import Vision
import CoreML
import UIKit
import os.log

@MainActor
class ImageAnalyzer: ObservableObject {
    @Published var isProcessing = false
    
    private let logger = Logger(subsystem: "com.jarvis.vision", category: "analyzer")
    private var classificationModel: VNCoreMLModel?
    
    init() {
        setupClassificationModel()
    }
    
    private func setupClassificationModel() {
        // Load a lightweight CoreML model for basic classification
        // In production, you'd bundle MobileNetV2 or similar
        guard let modelURL = Bundle.main.url(forResource: "MobileNetV2", withExtension: "mlmodelc"),
              let model = try? MLModel(contentsOf: modelURL),
              let visionModel = try? VNCoreMLModel(for: model) else {
            logger.warning("Classification model not available, using basic analysis")
            return
        }
        
        classificationModel = visionModel
        logger.info("Classification model loaded successfully")
    }
    
    func extractText(from image: UIImage) async -> String {
        isProcessing = true
        defer { isProcessing = false }
        
        guard let cgImage = image.cgImage else {
            logger.error("Failed to get CGImage")
            return ""
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    self.logger.error("OCR error: \(error)")
                    continuation.resume(returning: "")
                    return
                }
                
                let recognizedStrings = request.results?.compactMap { result in
                    (result as? VNRecognizedTextObservation)?.topCandidates(1).first?.string
                } ?? []
                
                let fullText = recognizedStrings.joined(separator: " ")
                self.logger.info("OCR extracted \(recognizedStrings.count) text segments")
                continuation.resume(returning: fullText)
            }
            
            // Configure for best accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                self.logger.error("OCR request failed: \(error)")
                continuation.resume(returning: "")
            }
        }
    }
    
    func classifyImage(_ image: UIImage) async -> String {
        guard let classificationModel = classificationModel,
              let cgImage = image.cgImage else {
            return "Unable to classify image"
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNCoreMLRequest(model: classificationModel) { request, error in
                if let error = error {
                    self.logger.error("Classification error: \(error)")
                    continuation.resume(returning: "Classification failed")
                    return
                }
                
                guard let results = request.results as? [VNClassificationObservation],
                      let topResult = results.first else {
                    continuation.resume(returning: "No classification results")
                    return
                }
                
                let confidence = Int(topResult.confidence * 100)
                let result = "\(topResult.identifier) (\(confidence)% confidence)"
                self.logger.info("Image classified as: \(result)")
                continuation.resume(returning: result)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                self.logger.error("Classification request failed: \(error)")
                continuation.resume(returning: "Classification failed")
            }
        }
    }
    
    func analyzeImageContent(_ image: UIImage) async -> ImageAnalysisResult {
        async let ocrText = extractText(from: image)
        async let classification = classifyImage(image)
        
        return ImageAnalysisResult(
            ocrText: await ocrText,
            classification: await classification,
            timestamp: Date()
        )
    }
}

struct ImageAnalysisResult {
    let ocrText: String
    let classification: String
    let timestamp: Date
}
