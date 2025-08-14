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
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
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
