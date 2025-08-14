import Foundation

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    enum AppMode {
        case offline, quickSearch, deepResearch
    }

    @Published var currentMode: AppMode = .offline
    @Published var selectedModel: ModelRuntime.ModelSize = .lite

    private init() {}
}
