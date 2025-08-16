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
            // MARK: AI Model
            Section("AI Model") {
                Picker("AI Model Size", selection: $appState.selectedModel) {
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

            // MARK: Network Modes
            Section("Network Modes") {
                Picker("Network Mode", selection: $appState.currentMode) {
                    Label("Offline", systemImage: "wifi.slash").tag(AppState.AppMode.offline)
                    Label("Quick Search", systemImage: "magnifyingglass").tag(AppState.AppMode.quickSearch)
                    Label("Deep Research", systemImage: "doc.text.magnifyingglass").tag(AppState.AppMode.deepResearch)
                    Label("Voice Control", systemImage: "mic").tag(AppState.AppMode.voiceControl)
                }
                .onChange(of: appState.currentMode, initial: false) { newMode in
                    networkGuard.setNetworkMode(newMode)
                    auditLog.logNetworkModeChange(newMode)
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

            // MARK: Privacy & Security
            Section("Privacy & Security") {
                NavigationLink("Network Audit Log") {
                    NetworkAuditView()
                }
                Button("Clear All Data") {
                    clearAllData()
                }
                .foregroundColor(.red)
            }

            // MARK: Data Engineering
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

            // MARK: Local Learning
            Section("Local Learning") {
                NavigationLink("Add Knowledge") {
                    AddKnowledgeView()
                }
                NavigationLink("Manage Embeddings") {
                    // Keep a single EmbeddingsView definition in its own file to avoid redeclaration
                    EmbeddingsView()
                }
            }

            // MARK: About
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
        // Clear any additional caches if needed
    }

    // Placeholder; adjust to your ModelRuntime as needed
    private func getModelSize() -> String {
        // If you have a concrete file path for the active model, compute size there.
        // Returning N/A avoids compile-time issues until wired to a real path.
        return "N/A"
    }
}

// MARK: - NetworkAuditView
struct NetworkAuditView: View {
    @EnvironmentObject private var auditLog: AuditLog

    var body: some View {
        List {
            Section("Recent Activity") {
                if auditLog.entries.isEmpty {
                    Text("No audit records available")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(auditLog.entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            if let title = entry.title, !title.isEmpty {
                                Text(title).font(.headline)
                            }
                            Text(entry.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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

// MARK: - PromptTemplatesView
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
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(template.name).font(.headline)
                                Spacer()
                                Button("Use") {
                                    manager.useTemplate(template)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            Text(template.content)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .font(.caption)
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
                Button("Export Templates") { manager.exportTemplates() }
            }
        }
        .navigationTitle("Prompt Templates")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSheet) { AddTemplateView() }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json, .plainText, UTType(importedAs: "net.daringfireball.markdown")],
            allowsMultipleSelection: false
        ) { result in
            manager.importTemplates(from: result)
        }
    }
}

struct AddTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category = "General"
    @State private var content = ""
    private let categories = ["General", "Code", "SQL", "Analysis", "Creative"]

    var body: some View {
        NavigationView {
            Form {
                TextField("Name", text: $name)
                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { c in
                        Text(c)
                    }
                }
                VStack(alignment: .leading) {
                    Text("Content").font(.headline)
                    TextEditor(text: $content).frame(minHeight: 200)
                }
            }
            .navigationTitle("Add Template")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        PromptTemplateManager.shared.addTemplate(
                            name: name,
                            content: content,
                            category: category
                        )
                        dismiss()
                    }
                    .disabled(name.isEmpty || content.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - SQLHelperView
struct SQLHelperView: View {
    @State private var query = ""
    @State private var result = ""
    @State private var errorMessage = ""

    var body: some View {
        Form {
            Section("SQL Query") {
                TextEditor(text: $query)
                    .frame(minHeight: 100)
                    .font(.system(.body, design: .monospaced))
            }
            Section {
                HStack {
                    Button("Validate") {
                        // TODO: validate query
                    }
                    Button("Execute") {
                        // TODO: execute query
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
                    Text(errorMessage).foregroundColor(.red)
                }
            }
        }
        .navigationTitle("SQL Assistant")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - CodeLinterView
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
                    // TODO: integrate with CodeLinter
                    lintResults = code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? ["No code entered"]
                        : ["No issues found"]
                }
            }
            Section("Results") {
                ForEach(lintResults, id: \.self) { issue in
                    Text(issue)
                }
            }
        }
        .navigationTitle("Code Linter")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - AddKnowledgeView
struct AddKnowledgeView: View {
    @State private var selectedFiles: [URL] = []
    @State private var isProcessing = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Knowledge")
                .font(.title2)
                .fontWeight(.semibold)

            Button("Select Documents") {
                // TODO: present document picker
            }
            .buttonStyle(.borderedProminent)

            if isProcessing {
                ProgressView("Processing...").padding(.top, 8)
            }

            if !selectedFiles.isEmpty {
                List(selectedFiles, id: \.self) { file in
                    Text(file.lastPathComponent)
                }
                .frame(minHeight: 150)
            }

            Spacer()

            Button("Close") { dismiss() }
        }
        .padding()
        .navigationTitle("Add Knowledge")
        .navigationBarTitleDisplayMode(.inline)
    }
}
