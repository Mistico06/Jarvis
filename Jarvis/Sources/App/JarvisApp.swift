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
                    Task {
                        await modelRuntime.initializeModels()
                    }
                }
                .onChange(of: appState.selectedModel) { newModel in
                    Task {
                        await modelRuntime.switchModel(to: newModel)
                    }
                }
        }
    }
    
    private func configureAppForOfflineFirst() {
        URLSessionConfiguration.default.allowsCellularAccess = false
        URLSessionConfiguration.default.allowsExpensiveNetworkAccess = false
    }
    
    private func requestPermissions() {
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVCaptureDevice.requestAccess(for: .video) { _ in }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var isModelLoaded = false
    @Published var currentMode: AppMode = .offline
    @Published var isNetworkActive = false
    
    // UPDATED enum with Identifiable & CaseIterable for UI bindings
    @Published var selectedModel: ModelSize = .lite
    
    enum AppMode {
        case offline, quickSearch, deepResearch
    }
    
    enum ModelSize: String, CaseIterable, Identifiable {
        case lite, max
        var id: String { rawValue }
    }
}
