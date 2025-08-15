import Foundation

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    /// Represents the operational mode of the app.
    enum AppMode {
        case offline
        case quickSearch
        case deepResearch
        case voiceControl
    }

    @Published var currentMode: AppMode = .offline
    @Published var selectedModel: ModelRuntime.ModelSize = .lite
    @Published var isVoiceControlActive: Bool = false

    private init() {}
}

// MARK: - ModelRuntime.ModelSize helpers used by UI

extension ModelRuntime.ModelSize {
    var displayName: String {
        switch self {
        case .lite: return "Lite (3B)"
        case .max:  return "Max (4B)"
        }
    }

    // UI uses this to show storage path; adapt to your bundle layout
    var modelBundlePath: String {
        // Produces: Models/lite-q4_K_M.mlc or Models/max-q4_K_M.mlc
        return "Models/\(self.rawValue)-q4_K_M.mlc"
    }
}
