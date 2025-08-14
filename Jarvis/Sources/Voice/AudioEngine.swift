import Foundation
import Speech
import AVFoundation
import os.log

@MainActor
class AudioEngine: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var transcriptionText = ""
    
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var inputNode: AVAudioInputNode?
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    private let logger = Logger(subsystem: "com.jarvis.voice", category: "audio")
    
    override init() {
        super.init()
        setupSpeechRecognizer()
        speechSynthesizer.delegate = self
    }
    
    private func setupSpeechRecognizer() {
        // Initialize speech recognizer with on-device requirement
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        speechRecognizer?.defaultTaskHint = .dictation
        
        // Request authorization
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.logger.info("Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    self?.logger.error("Speech recognition not authorized: \(status.rawValue)")
                @unknown default:
                    self?.logger.error("Speech recognition unknown status")
                }
            }
        }
    }
    
    func startRecording(completion: @escaping (String) -> Void) {
        guard let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            logger.error("Speech recognizer not available")
            return
        }
        
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("Failed to setup audio session: \(error)")
            return
        }
        
        inputNode = audioEngine.inputNode
        
        // Create recognition request with on-device requirement
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            logger.error("Failed to create recognition request")
            return
        }
        
        // CRITICAL: Force on-device processing
        recognitionRequest.requiresOnDeviceRecognition = true
        recognitionRequest.shouldReportPartialResults = true
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            var isFinal = false
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self?.transcriptionText = transcription
                }
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self?.audioEngine.stop()
                self?.inputNode?.removeTap(onBus: 0)
                self?.recognitionRequest = nil
                self?.recognitionTask = nil
                
                if isFinal, let finalText = self?.transcriptionText {
                    DispatchQueue.main.async {
                        completion(finalText)
                    }
                }
            }
        }
        
        // Configure audio tap
        let recordingFormat = inputNode?.outputFormat(forBus: 0)
        inputNode?.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            logger.info("Recording started")
        } catch {
            logger.error("Failed to start audio engine: \(error)")
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isRecording = false
        logger.info("Recording stopped")
    }
    
    func speak(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        speechSynthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
}

extension AudioEngine: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        logger.info("Speech synthesis started")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        logger.info("Speech synthesis finished")
    }
}
