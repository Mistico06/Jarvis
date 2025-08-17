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
        // Keep side effects on the main actor to satisfy concurrency rules.
        // If your toolchain balks at `@MainActor` in the Task closure,
        // use the fallback shown below.
        Task {
            await MainActor.run {
                if #available(iOS 17.0, *) {
                    AVAudioApplication.shared.requestRecordPermission { granted in
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
                    // Load default model at launch
                    await modelRuntime.initializeModels()
                    // Mirror current AppState into NetworkGuard on start
                    networkGuard.setNetworkMode(appState.currentMode)
                }
        }
    }
}
