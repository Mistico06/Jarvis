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

    /// ✅ Combined version of permission requests with proper availability checks
    private func requestPermissions() {
        if #available(macOS 10.14, *) {
            AVCaptureDevice.requestAccess(for: .video) { _ in }
        }

        if #available(macOS 10.15, *) {
            SFSpeechRecognizer.requestAuthorization { _ in }
        }

        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }

    private func configureAppForOfflineFirst() {
        URLSessionConfiguration.default.allowsCellularAccess = false
        URLSessionConfiguration.default.allowsExpensiveNetworkAccess = false
    }
}
