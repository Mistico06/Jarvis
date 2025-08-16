import Foundation

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

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

// Helpers used by UI for display and storage path
extension ModelRuntime.ModelSize {
    var displayName: String {
        switch self {
        case .lite: return "Lite (3B)"
        case .max:  return "Max (4B)"
        }
    }

    // Produces: Models/lite-q4_K_M.mlc or Models/max-q4_K_M.mlc
    var modelBundlePath: String {
        return "Models/\(self.rawValue)-q4_K_M.mlc"
    }
}
