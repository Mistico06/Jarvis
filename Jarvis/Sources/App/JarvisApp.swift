import SwiftUI
import Speech
import AVFoundation

@main
struct JarvisApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var modelRuntime = ModelRuntime.shared
    @StateObject private var networkGuard = NetworkGuard.shared
    
    init() {
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
        // NOTE: This modifies the default config instance, which might be too late if sessions exist
        // Consider creating custom URLSessionConfiguration and using it in your networking stack
        URLSessionConfiguration.default.allowsCellularAccess = false
        URLSessionConfiguration.default.allowsExpensiveNetworkAccess = false
    }
    
    private func requestPermissions() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                appState.microphonePermissionGranted = granted
            }
        }
        
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                appState.speechRecognitionStatus = status
            }
        }
        
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                appState.cameraPermissionGranted = granted
            }
        }
    }
    
    private func initializeApp() {
        Task {
            await modelRuntime.initializeModels()
            DispatchQueue.main.async {
                appState.isModelLoaded = true
            }
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var isModelLoaded = false
    @Published var currentMode: AppMode = .offline
    @Published var isNetworkActive = false
    @Published var selectedModel: ModelSize = .lite
    
    // Permissions tracking added for better state handling
    @Published var microphonePermissionGranted: Bool = false
    @Published var speechRecognitionStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var cameraPermissionGranted: Bool = false
    
    enum AppMode {
        case offline, quickSearch, deepResearch
    }
    
    enum ModelSize {
        case lite, max
    }
}
