import SwiftUI

#if os(iOS)
import AVFoundation
#endif

@available(macOS 11.0, *)
@main
struct JarvisApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var modelRuntime = ModelRuntime.shared
    @StateObject private var networkGuard = NetworkGuard.shared

    init() {
        #if os(iOS)
        // Request microphone permission early
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if !granted {
                print("Microphone access denied.")
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(modelRuntime)
                .environmentObject(networkGuard)
        }
    }
}
