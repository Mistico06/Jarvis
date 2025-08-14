import SwiftUI
import Speech
import AVFoundation

@main
struct JarvisApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var modelRuntime = ModelRuntime.shared
    @StateObject private var networkGuard = NetworkGuard.shared
    
    init() {
        // Configure app for offline-first operation
        configureAppForOfflineFirst()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(modelRuntime)
                .environmentObject(networkGuard)
                .onAppear {
                    requestPermissions()
                    initializeApp()
                }
        }
    }
    
    private func configureAppForOfflineFirst() {
        // Disable automatic network requests
        URLSessionConfiguration.default.allowsCellularAccess = false
        URLSessionConfiguration.default.allowsExpensiveNetworkAccess = false
    }
    
    private func requestPermissions() {
        // Request microphone permission for on-device speech
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        
        // Request speech recognition permission with on-device requirement
        SFSpeechRecognizer.requestAuthorization { _ in }
        
        // Request camera permission for OCR
        AVCaptureDevice.requestAccess(for: .video) { _ in }
    }
    
    private func initializeApp() {
        Task {
            await modelRuntime.initializeModels()
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var isModelLoaded = false
    @Published var currentMode: AppMode = .offline
    @Published var isNetworkActive = false
    @Published var selectedModel: ModelSize = .lite
    
    enum AppMode {
        case offline, quickSearch, deepResearch
    }
    
    enum ModelSize {
        case lite, max
    }
}
