import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var modelRuntime: ModelRuntime
    @EnvironmentObject private var networkGuard: NetworkGuard
    @StateObject private var auditLog = AuditLog.shared

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("AI Model") {
                    Picker("Model Size", selection: $appState.selectedModel) {
                        Text("Lite (3B) – Faster").tag(ModelRuntime.ModelSize.lite)
                        Text("Max (4B) – Smarter").tag(ModelRuntime.ModelSize.max)
                    }
                    .onChange(of: appState.selectedModel) { newModel in
                        Task { await modelRuntime.switchModel(to: newModel) }
                    }

                    if modelRuntime.isModelLoaded {
                        HStack {
                            Text("Performance")
                            Spacer()
                            Text("\(modelRuntime.tokensPerSecond, specifier: "%.1f") tok/s")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Network Modes") {
                    Picker("Mode", selection: $appState.currentMode) {
                        Label("Offline", systemImage: "wifi.slash")
                            .tag(AppState.AppMode.offline)
                        Label("Quick Search", systemImage: "magnifyingglass")
                            .tag(AppState.AppMode.quickSearch)
                        Label("Deep Research", systemImage: "doc.text.magnifyingglass")
                            .tag(AppState.AppMode.deepResearch)
                        Label("Voice Control", systemImage: "mic")
                            .tag(AppState.AppMode.voiceControl)
                    }
                    .onChange(of: appState.currentMode) { newMode in
                        networkGuard.setNetworkMode(newMode)
                    }

                    if appState.currentMode != .offline {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("Network requests enabled")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }

                Section("Privacy & Security") {
                    NavigationLink("Network Audit Log") {
                        NetworkAuditView()
                            .environmentObject(auditLog)
                    }
                    Button("Clear All Data") {
                        clearAllData()
                    }
                    .foregroundColor(.red)
                }

                Section("Data Engineering") {
                    NavigationLink("Prompt Templates") {
                        PromptTemplatesView()
                    }
                    NavigationLink("SQL Assistant") {
                        SQLHelperView()
                    }
                    NavigationLink("Code Linter") {
                        CodeLinterView()
                    }
                }

                Section("Local Learning") {
                    NavigationLink("Add Knowledge") {
                        AddKnowledgeView()
                    }
                    NavigationLink("Manage Embeddings") {
                        EmbeddingsView()
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Model Storage")
                        Spacer()
                        Text(getModelStorageSize())
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func clearAllData() {
        ConversationStore.shared.clearAll()
        auditLog.clearLogs()
        LocalEmbeddings.shared.clearCache()
    }

    private func getModelStorageSize() -> String {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docsURL.appendingPathComponent(modelRuntime.currentModel.modelBundlePath)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let byteCount = attributes[.size] as? Int64 else {
            return "0 MB"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: byteCount)
    }
}
