import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            SettingsFormView()
        }
    }
}

private struct SettingsFormView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var modelRuntime: ModelRuntime
    @EnvironmentObject private var networkGuard: NetworkGuard
    @EnvironmentObject private var auditLog: AuditLog
    @EnvironmentObject private var knowledgeManager: KnowledgeManager
    @EnvironmentObject private var embeddingsManager: EmbeddingsManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            // === Begin your Section code, unchanged ===
            Section(header: Text("AI Model")) {
                Picker("Model Size", selection: $appState.selectedModel) {
                    Text("Lite (3B) – Faster").tag(ModelRuntime.ModelSize.lite)
                    Text("Max (4B) – Smarter").tag(ModelRuntime.ModelSize.max)
                }
                .onChange(of: appState.selectedModel, initial: false) {
                    Task { await modelRuntime.switchModel(to: appState.selectedModel) }
                }

                if modelRuntime.isLoaded {
                    HStack {
                        Text("Performance")
                        Spacer()
                        Text("\(modelRuntime.tokensPerSecond, specifier: "%.1f") tok/s")
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(header: Text("Network Modes")) {
                Picker("Mode", selection: $appState.currentMode) {
                    Label("Offline", systemImage: "wifi.slash").tag(AppState.AppMode.offline)
                    Label("Quick Search", systemImage: "magnifyingglass").tag(AppState.AppMode.quickSearch)
                    Label("Deep Research", systemImage: "doc.text.magnifyingglass").tag(AppState.AppMode.deepResearch)
                    Label("Voice Control", systemImage: "mic").tag(AppState.AppMode.voiceControl)
                }
                .onChange(of: appState.currentMode, initial: false) {
                    networkGuard.setNetworkMode(appState.currentMode)
                    auditLog.logNetworkModeChange(appState.currentMode)
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

            Section(header: Text("Privacy & Security")) {
                NavigationLink("Network Audit Log") {
                    NetworkAuditView()
                }
                Button("Clear All Data") {
                    clearAllData()
                }
                .foregroundColor(.red)
            }

            Section(header: Text("Data Engineering")) {
                NavigationLink("Prompt Templates") { PromptTemplatesView() }
                NavigationLink("SQL Assistant") { SQLHelperView() }
                NavigationLink("Code Linter") { CodeLinterView() }
            }

            Section(header: Text("Local Learning")) {
                NavigationLink("Add Knowledge") { AddKnowledgeView() }
                NavigationLink("Manage Embeddings") { EmbeddingsView() }
            }

            Section(header: Text("About")) {
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
            // === End your Section code ===
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func clearAllData() {
        ConversationStore.shared.clearAll()
        auditLog.clearLogs()
        // LocalEmbeddings.shared.clearCache() // if present
    }

    private func getModelStorageSize() -> String {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docsURL.appendingPathComponent(modelRuntime.currentModel.modelBundlePath)
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
            let byteCount = attributes[.size] as? Int64
        else {
            return "0 MB"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: byteCount)
    }
}

// -- the rest of your NetworkAuditView, PromptTemplatesView, etc. remain unchanged.
