import Foundation

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    /// Represents the operational mode of the app.
    enum AppMode {
        case offline
        case quickSearch
        case deepResearch
        case voiceControl   // added voice control mode
    }

    @Published var currentMode: AppMode = .offline
    @Published var selectedModel: ModelRuntime.ModelSize = .lite
    @Published var isVoiceControlActive: Bool = false  // track voice control state

    private init() {}
}

// MARK: - ModelRuntime.ModelSize extension with displayName and modelPath

extension ModelRuntime.ModelSize {
    var displayName: String {
        switch self {
        case .lite: return "Lite (3B)"
        case .max: return "Max (4B)"
        }
    }

    var modelPath: String {
        // This should match how you're saving/embedding MLC models
        return "Models/\(self.rawValue)-q4_K_M.mlc"
    }
}
