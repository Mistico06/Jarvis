import SwiftUI
import AVFoundation  // ✅ Remove conditional since you only target iOS

@main  // ✅ Remove @available since you only target iOS
struct JarvisApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var modelRuntime = ModelRuntime.shared
    @StateObject private var networkGuard = NetworkGuard.shared

    init() {
        // ✅ Remove #if os(iOS) since you only target iOS
        // Request microphone permission early
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if !granted {
                print("Microphone access denied.")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(modelRuntime)
                .environmentObject(networkGuard)
                .task {
                    // ✅ Initialize models when app starts
                    await modelRuntime.initializeModels()
                }
        }
    }
}
