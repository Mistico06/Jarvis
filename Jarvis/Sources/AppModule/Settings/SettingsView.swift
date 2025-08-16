import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

// Main Settings and nested form view
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
            Section("AI Model") {
                Picker("AI Model Size", selection: $appState.selectedModel) {
                    Text("Lite (3B) – Faster").tag(ModelRuntime.ModelSize.lite)
                    Text("Max (4B) – Smarter").tag(ModelRuntime.ModelSize.max)
                }.onChange(of: appState.selectedModel, initial: false) {
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
            
            Section("Network Modes") {
                Picker("Network Mode", selection: $appState.currentMode) {
                    Label("Offline", systemImage: "wifi.slash").tag(AppState.AppMode.offline)
                    Label("Quick Search", systemImage: "magnifyingglass").tag(AppState.AppMode.quickSearch)
                    Label("Deep Research", systemImage: "doc.text.magnifyingglass").tag(AppState.AppMode.deepResearch)
                    Label("Voice Control", systemImage: "mic").tag(AppState.AppMode.voiceControl)
                }.onChange(of: appState.currentMode, initial: false) {
                    networkGuard.setNetworkMode($0)
                    auditLog.logNetworkChange($0)
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
                    Text(getModelSize())
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

    private func clearAllData() {
        ConversationStore.shared.clearAll()
        auditLog.clearLogs()
        // Consider clearing caches or other persistence if needed
    }

    private func getModelSize() -> String {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        // Adjust this path according to your ModelRuntime implementation
        let fileURL = docsURL.appendingPathComponent(modelRuntime.currentModel.bundleFilePath)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? UInt64 else {
            return "N/A"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

// MARK: - NetworkAuditView Implementation
struct NetworkAuditView: View {
    @EnvironmentObject private var auditLog: AuditLog

    var body: some View {
        List {
            Section("Recent Activity") {
                if auditLog.entries.isEmpty {
                    Text("No audit records available").foregroundColor(.secondary)
                } else {
                    ForEach(auditLog.entries) { entry in
                        Text(entry.description)
                    }
                }
            }
            Section("Actions") {
                Button("Clear Audit Log") {
                    auditLog.clearLogs()
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Network Audit")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - PromptTemplatesView Implementation
struct PromptTemplatesView: View {
    @StateObject private var manager = PromptTemplateManager.shared
    @State private var showAddSheet = false
    @State private var showImporter = false

    var body: some View {
        List {
            Section("Templates") {
                if manager.templates.isEmpty {
                    Text("No templates yet").foregroundColor(.secondary)
                } else {
                    ForEach(manager.templates) { template in
                        VStack(alignment: .leading) {
                            Text(template.name).bold()
                            Text(template.content).foregroundColor(.secondary).lineLimit(2)
                        }
                    }
                    .onDelete { indices in
                        manager.remove(atOffsets: indices)
                    }
                }
            }
            Section("Actions") {
                Button("Add Template") { showAddSheet = true }
                Button("Import Templates") { showImporter = true }
                Button("Export Templates") {
                    manager.exportTemplates()
                }
            }
        }
        .navigationTitle("Prompt Templates")
        .sheet(isPresented: $showAddSheet) {
            AddTemplateView()
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .plainText, .init("net.daringfireball.markdown")], allowsMultipleSelection: false) { result in
            manager.importTemplates(from: result)
        }
    }
}

struct AddTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category = "General"
    @State private var content = ""
    let categories = ["General", "Code", "SQL", "Analysis", "Creative"]

    var body: some View {
        NavigationView {
            Form {
                TextField("Name", text: $name)
                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { c in
                        Text(c)
                    }
                }
                TextEditor(text: $content)
                    .frame(minHeight: 200)
            }
            .navigationTitle("Add Template")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Add save functionality
                        dismiss()
                    }.disabled(name.isEmpty || content.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - SQLHelperView Implementation
struct SQLHelperView: View {
    @State private var query = ""
    @State private var result = ""
    @State private var errorMessage = ""

    var body: some View {
        Form {
            Section("SQL Query") {
                TextEditor(text: $query)
                    .frame(minHeight: 100)
            }
            Section {
                HStack {
                    Button("Validate") {
                        // Add validation logic here
                    }
                    Button("Execute") {
                        // Add execution logic here
                    }
                }
            }
            Section("Results") {
                if errorMessage.isEmpty {
                    ScrollView {
                        Text(result)
                            .font(.system(.body, design: .monospaced))
                    }
                    .frame(minHeight: 200)
                } else {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("SQL Assistant")
    }
}

// MARK: - CodeLinterView Implementation
struct CodeLinterView: View {
    @State private var code = ""
    @State private var lintResults: [String] = []

    var body: some View {
        Form {
            Section("Code") {
                TextEditor(text: $code)
                    .frame(minHeight: 200)
                    .font(.system(.body, design: .monospaced))
            }
            Section {
                Button("Lint") {
                    // Add lint logic here
                    lintResults = ["No issues found"] // Placeholder
                }
            }
            Section("Results") {
                ForEach(lintResults, id: \.self) { issue in
                    Text(issue)
                }
            }
        }
        .navigationTitle("Code Linter")
    }
}

// MARK: - AddKnowledgeView Implementation
struct AddKnowledgeView: View {
    @State private var selectedFiles: [URL] = []
    @State private var isProcessing = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Text("Add Knowledge")
                .font(.largeTitle)
                .padding()

            Button("Select Documents") {
                // Open document picker
            }
            .padding()

            if isProcessing {
                ProgressView("Processing...")
                    .padding()
            }

            List(selectedFiles, id: \.self) { file in
                Text(file.lastPathComponent)
            }

            Spacer()

            Button("Close") { dismiss() }
                .padding()
        }
        .padding()
    }
}

// MARK: - EmbeddingsView Implementation
struct EmbeddingsView: View {
    @EnvironmentObject private var embeddingsManager: EmbeddingsManager

    var body: some View {
        List {
            if embeddingsManager.items.isEmpty {
                Text("No embeddings added yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(embeddingsManager.items) { item in
                    Text(item.name)
                }
                .onDelete { indices in
                    embeddingsManager.remove(atOffsets: indices)
                }
            }
        }
        .navigationTitle("Manage Embeddings")
    }
}
