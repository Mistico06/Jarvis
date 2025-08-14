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
                // Model Selection
                Section("AI Model") {
                    Picker("Model Size", selection: $appState.selectedModel) {
                        Text("Lite (3B) - Faster").tag(AppState.ModelSize.lite)
                        Text("Max (4B) - Smarter").tag(AppState.ModelSize.max)
                    }
                    .onChange(of: appState.selectedModel) { newModel in
                        Task {
                            await modelRuntime.loadModel(size: newModel == .lite ? .lite : .max)
                        }
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
                
                // Network Modes
                Section("Network Modes") {
                    Picker("Mode", selection: $appState.currentMode) {
                        Label("Offline", systemImage: "wifi.slash")
                            .tag(AppState.AppMode.offline)
                        Label("Quick Search", systemImage: "magnifyingglass")
                            .tag(AppState.AppMode.quickSearch)
                        Label("Deep Research", systemImage: "doc.text.magnifyingglass")
                            .tag(AppState.AppMode.deepResearch)
                    }
                    .onChange(of: appState.currentMode) { newMode in
                        networkGuard.setNetworkMode(newMode)
                        appState.isNetworkActive = newMode != .offline
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
                
                // Privacy & Security
                Section("Privacy & Security") {
                    NavigationLink("Network Audit Log") {
                        NetworkAuditView()
                    }
                    
                    Button("Clear All Data") {
                        clearAllData()
                    }
                    .foregroundColor(.red)
                }
                
                // Data Engineering
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
                
                // Local Learning
                Section("Local Learning") {
                    NavigationLink("Add Knowledge") {
                        AddKnowledgeView()
                    }
                    
                    NavigationLink("Manage Embeddings") {
                        EmbeddingsView()
                    }
                }
                
                // App Info
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("2024.08.14")
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
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func clearAllData() {
        // Clear conversations
        ConversationStore.shared.clearAll()
        
        // Clear audit logs
        auditLog.clearLogs()
        
        // Clear embeddings cache
        LocalEmbeddings.shared.clearCache()
    }
    
    private func getModelStorageSize() -> String {
        let modelPaths = [
            modelRuntime.currentModel.modelPath
        ]
        
        var totalSize: Int64 = 0
        for path in modelPaths {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
               let size = attributes[.size] as? Int64 {
                totalSize += size
            }
        }
        
        return ByteCountFormatter().string(fromByteCount: totalSize)
    }
}
