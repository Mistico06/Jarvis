import Foundation
import os.log
import AVFoundation
import Speech

@MainActor
final class AudioEngine: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var transcriptionText = ""

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechSynthesizer = AVSpeechSynthesizer()

    private let logger = Logger(subsystem: "com.jarvis.voice", category: "audio")

    override init() {
        super.init()
        speechSynthesizer.delegate = self
        SFSpeechRecognizer.requestAuthorization { status in
            if case .authorized = status {
                // ok
            } else {
                self.logger.warning("Speech recognition not authorized: \(status.rawValue)")
            }
        }
    }

    func startRecording(completion: @escaping (String) -> Void) {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            logger.warning("Speech recognizer unavailable")
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }

        let inputNode = audioEngine.inputNode
        request.shouldReportPartialResults = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.transcriptionText = text
                    completion(text)
                }
            }
            if let error = error {
                self.logger.error("Recognition error: \(error.localizedDescription)")
                self.stopRecording()
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            logger.info("Started recording")
        } catch {
            logger.error("AudioEngine start error: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        isRecording = false
        logger.info("Stopped recording")
    }

    func speak(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        speechSynthesizer.speak(utterance)
        logger.info("Speaking text")
    }

    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        logger.info("Stopped speaking")
    }
}

extension AudioEngine: AVSpeechSynthesizerDelegate {}
