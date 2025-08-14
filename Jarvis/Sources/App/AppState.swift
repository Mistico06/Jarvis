import Foundation

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    enum AppMode {
        case offline
        case quickSearch
        case deepResearch
    }

    @Published var currentMode: AppMode = .offline

    private init() {}
}
