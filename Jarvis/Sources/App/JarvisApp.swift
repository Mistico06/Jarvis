import SwiftUI

#if os(iOS)
import AVFoundation
#endif

@available(macOS 11.0, *)
@main
struct JarvisApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var modelRuntime = ModelRuntime.shared
    @StateObject private var networkGuard = NetworkGuard.shared

    init() {
        #if os(iOS)
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            print("Record permission granted: \(granted)")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: appState.selectedModel) { newModel in
                    Task {
                        await modelRuntime.switchModel(to: newModel)
                    }
                }
        }
    }
}
