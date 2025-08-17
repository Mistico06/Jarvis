import SwiftUI
import AVFoundation

@main
struct JarvisApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var modelRuntime = ModelRuntime.shared
    @StateObject private var networkGuard = NetworkGuard.shared
    @StateObject private var auditLog = AuditLog.shared
    @StateObject private var knowledgeManager = KnowledgeManager.shared
    @StateObject private var embeddingsManager = EmbeddingsManager.shared

    init() {
        Task {
            await MainActor.run {
                if #available(iOS 17.0, *) {
                    // Use static API (no .shared) for Xcode 16.2 SDK
                    AVAudioApplication.requestRecordPermission { granted in
                        if !granted { print("Microphone access denied.") }
                    }
                } else {
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        if !granted { print("Microphone access denied.") }
                    }
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(modelRuntime)
                .environmentObject(networkGuard)
                .environmentObject(auditLog)
                .environmentObject(knowledgeManager)
                .environmentObject(embeddingsManager)
                .task {
                    await modelRuntime.initializeModels()
                    networkGuard.setNetworkMode(appState.currentMode)
                }
        }
    }
}
