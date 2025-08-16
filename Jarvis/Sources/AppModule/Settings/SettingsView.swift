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
                    // Keep EmbeddingsView in its own file to avoid redeclaration conflicts
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
        embeddingsManager.clearAll()
        knowledgeManager.clearSelection()
    }

    // Attempts to compute the size of the active model on disk.
    // Assumes modelRuntime exposes a URL (or path) to the current model bundle or file.
    // Falls back to "N/A" if path isn't available yet.
    private func getModelSize() -> String {
        // Preferred: a concrete URL from your runtime
        // e.g., modelRuntime.currentModelURL or modelRuntime.currentModel.bundleURL
        if let url = modelRuntime.currentModelURL {
            return byteCount(at: url)
        }
        // Alternative: build Documents path if you only have a relative path
        if let relativePath = modelRuntime.currentModelRelativePath {
            let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = docsURL.appendingPathComponent(relativePath)
            return byteCount(at: fileURL)
        }
        // Fallback
        return "N/A"
    }

    private func byteCount(at url: URL) -> String {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return "N/A" }

        var total: Int64 = 0

        if isDir.boolValue {
            if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [], errorHandler: nil) {
                for case let fileURL as URL in enumerator {
                    if let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                        total += Int64(size)
                    }
                }
            }
        } else {
            if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                total = Int64(size)
            }
        }

        let fmt = ByteCountFormatter()
        fmt.allowedUnits = [.useMB]
        fmt.countStyle = .file
        return fmt.string(fromByteCount: total)
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
                                Button("Use") { manager.useTemplate(template) }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                            Text(template.content)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .font(.caption)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                manager.deleteTemplate(template)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { offsets in
                        manager.remove(atOffsets: offsets)
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
                        validateSQL()
                    }
                    .buttonStyle(.bordered)

                    Button("Execute") {
                        executeSQL()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            Section("Results") {
                if errorMessage.isEmpty {
                    ScrollView {
                        Text(result)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
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

    private func validateSQL() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Query is empty."
            result = ""
            return
        }
        // Naive validation: ensure statement ends with ; and contains common verbs
        let verbs = ["select", "update", "insert", "delete", "create", "drop", "alter"]
        let lower = trimmed.lowercased()
        guard trimmed.hasSuffix(";") else {
            errorMessage = "Query should end with a semicolon."
            result = ""
            return
        }
        guard verbs.contains(where: { lower.contains($0) }) else {
            errorMessage = "Query does not include a recognized SQL verb."
            result = ""
            return
        }
        errorMessage = ""
        result = "Validation OK."
    }

    // Minimal in-memory execution simulation (without external I/O)
    // For real execution, wire to your SQLHelper/SQLite.swift layer.
    private func executeSQL() {
        validateSQL()
        guard errorMessage.isEmpty else { return }
        let lower = query.lowercased()
        if lower.starts(with: "select") {
            result = """
            id | name      | active
            ---+-----------+-------
            1  | Alice     | 1
            2  | Bob       | 0
            """
        } else {
            result = "Statement executed successfully."
        }
    }
}

// MARK: - CodeLinterView
struct CodeLinterView: View {
    @State private var code = ""
    @State private var lintResults: [String] = []
    @State private var language = "Swift"
    private let languages = ["Swift", "Python", "JavaScript", "TypeScript", "Java", "C++", "Go", "Rust"]

    var body: some View {
        Form {
            Section("Language") {
                Picker("Language", selection: $language) {
                    ForEach(languages, id: \.self) { lang in
                        Text(lang)
                    }
                }
                .pickerStyle(.menu)
            }
            Section("Code") {
                TextEditor(text: $code)
                    .frame(minHeight: 200)
                    .font(.system(.body, design: .monospaced))
            }
            Section {
                HStack {
                    Button("Lint") {
                        lint()
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Format") {
                        code = format(code: code, language: language)
                    }
                    .buttonStyle(.bordered)
                }
            }
            Section("Results") {
                if lintResults.isEmpty {
                    Text("No results yet").foregroundColor(.secondary)
                } else {
                    ForEach(lintResults, id: \.self) { issue in
                        Text(issue)
                    }
                }
            }
        }
        .navigationTitle("Code Linter")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func lint() {
        var issues: [String] = []
        let lines = code.components(separatedBy: .newlines)
        for (i, line) in lines.enumerated() {
            if line.count > 120 {
                issues.append("Line \(i+1): Line exceeds 120 characters.")
            }
            if line.hasSuffix(" ") {
                issues.append("Line \(i+1): Trailing whitespace.")
            }
        }
        if language == "Swift" && !code.contains("{") {
            issues.append("Swift: Consider adding braces for blocks if missing.")
        }
        lintResults = issues.isEmpty ? ["No issues found"] : issues
    }

    private func format(code: String, language: String) -> String {
        // Very light formatter: trim trailing spaces, ensure newline at EOF
        let lines = code.components(separatedBy: .newlines)
        let trimmedLines = lines.map { $0.replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression) }
        var joined = trimmedLines.joined(separator: "\n")
        if !joined.hasSuffix("\n") { joined.append("\n") }
        return joined
    }
}

// MARK: - AddKnowledgeView
struct AddKnowledgeView: View {
    @State private var selectedFiles: [URL] = []
    @State private var isProcessing = false
    @State private var processedCount = 0
    @State private var showImporter = false
    @Environment(\.dismiss) private var dismiss

    private var allowedDocTypes: [UTType] {
        var types: [UTType] = [.pdf, .text, .rtf, .plainText]
        types.append(UTType(importedAs: "net.daringfireball.markdown"))
        return types
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Knowledge")
                .font(.title2)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                Button("Select Documents") { showImporter = true }
                    .buttonStyle(.borderedProminent)
                Button("Clear Selection") {
                    selectedFiles.removeAll()
                    processedCount = 0
                }
                .buttonStyle(.bordered)
                .disabled(selectedFiles.isEmpty || isProcessing)
            }

            if !selectedFiles.isEmpty {
                List {
                    ForEach(selectedFiles, id: \.self) { url in
                        HStack {
                            Image(systemName: "doc.text")
                            Text(url.lastPathComponent)
                            Spacer()
                        }
                    }
                }
                .frame(minHeight: 150, maxHeight: 250)
            } else {
                Text("No documents selected")
                    .foregroundColor(.secondary)
            }

            if isProcessing {
                ProgressView("Processing documents… \(processedCount)/\(selectedFiles.count)")
            }

            HStack(spacing: 12) {
                Button("Process") { processSelected() }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedFiles.isEmpty || isProcessing)

                Button("Close") { dismiss() }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .navigationTitle("Add Knowledge")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: allowedDocTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                selectedFiles.append(contentsOf: urls)
            case .failure(let err):
                print("Import failed: \(err.localizedDescription)")
            }
        }
    }

    private func processSelected() {
        guard !selectedFiles.isEmpty else { return }
        isProcessing = true
        processedCount = 0
        // Simulate async processing
        Task {
            for _ in selectedFiles {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s each
                processedCount += 1
            }
            isProcessing = false
        }
    }
}
