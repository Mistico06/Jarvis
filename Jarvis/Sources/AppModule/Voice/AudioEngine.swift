import Foundation
import os.log
import AVFoundation
#if os(iOS)
import Speech
#endif

@MainActor
class AudioEngine: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var transcriptionText = ""

    #if os(iOS)
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechSynthesizer = AVSpeechSynthesizer()
    #endif

    private let logger = Logger(subsystem: "com.jarvis.voice", category: "audio")

    override init() {
        super.init()
        #if os(iOS)
        speechSynthesizer.delegate = self
        SFSpeechRecognizer.requestAuthorization { status in
            switch status {
            case .authorized: break
            default:
                self.logger.warning("Speech recognition not authorized: \(status.rawValue)")
            }
        }
        #endif
    }

    #if os(iOS)
    func startRecording(completion: @escaping (String) -> Void) {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            logger.warning("Speech recognizer unavailable")
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }

        let inputNode = audioEngine.inputNode
        request.shouldReportPartialResults = true

        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            if let result = result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
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
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
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
    #else
    func startRecording(completion: @escaping (String) -> Void) {
        logger.warning("Speech unavailable")
    }
    func stopRecording() {
        logger.warning("Speech unavailable")
    }
    func speak(text: String) {
        logger.warning("Speech unavailable")
    }
    func stopSpeaking() {
        logger.warning("Speech unavailable")
    }
    #endif
}

#if os(iOS)
extension AudioEngine: AVSpeechSynthesizerDelegate {
    // Add methods if you need callbacks for start/finish of speech
}
#endif
