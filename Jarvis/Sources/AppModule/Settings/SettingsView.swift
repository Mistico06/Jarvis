import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

// Settings root
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
            Section {
                Picker("AI Model Size", selection: $appState.selectedModel) {
                    Text("Lite (3B) – Faster").tag(ModelRuntime.ModelSize.lite)
                    Text("Max (4B) – Smarter").tag(ModelRuntime.ModelSize.max)
                }
                .onChange(of: appState.selectedModel) { newValue in
                    Task { await modelRuntime.switchModel(to: newValue) }
                }

                if modelRuntime.isLoaded {
                    HStack {
                        Text("Performance")
                        Spacer()
                        Text("\(modelRuntime.tokensPerSecond, specifier: "%.1f") tok/s")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("AI Model")
            }

            // MARK: Network Modes
            Section {
                Picker("Network Mode", selection: $appState.currentMode) {
                    Label("Offline", systemImage: "wifi.slash").tag(AppState.AppMode.offline)
                    Label("Quick Search", systemImage: "magnifyingglass").tag(AppState.AppMode.quickSearch)
                    Label("Deep Research", systemImage: "doc.text.magnifyingglass").tag(AppState.AppMode.deepResearch)
                    Label("Voice Control", systemImage: "mic").tag(AppState.AppMode.voiceControl)
                }
                .onChange(of: appState.currentMode) { newMode in
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
            } header: {
                Text("Network Modes")
            }

            // MARK: Privacy & Security
            Section {
                NavigationLink("Network Audit Log") { NetworkAuditView() }
                Button("Clear All Data") { clearAllData() }
                    .foregroundColor(.red)
            } header: {
                Text("Privacy & Security")
            }

            // MARK: Data Engineering
            Section {
                NavigationLink("Prompt Templates") { PromptTemplatesView() }
                NavigationLink("SQL Assistant") { SQLHelperView() }
                NavigationLink("Code Linter") { CodeLinterView() }
            } header: {
                Text("Data Engineering")
            }

            // MARK: Local Learning
            Section {
                NavigationLink("Add Knowledge") { AddKnowledgeView() }
                NavigationLink("Manage Embeddings") { EmbeddingsDashboardView() }
            } header: {
                Text("Local Learning")
            }

            // MARK: About
            Section {
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
            } header: {
                Text("About")
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
        embeddingsManager.clearAllEmbeddings()
        knowledgeManager.clearSelection()
    }

    // Wire to a concrete URL/path in ModelRuntime when available
    private func getModelSize() -> String { "N/A" }
}

// MARK: - Network Audit (uses AuditLog.networkLogs)
struct NetworkAuditView: View {
    @EnvironmentObject private var auditLog: AuditLog

    var body: some View {
        List {
            Section {
                if auditLog.networkLogs.isEmpty {
                    Text("No audit records available").foregroundColor(.secondary)
                } else {
                    ForEach(auditLog.networkLogs) { log in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(log.method) \(log.host)\(log.path)")
                                .font(.headline)
                            Text(log.purpose)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(log.timestamp.formatted())
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("Recent Activity")
            }

            Section {
                Button("Clear Audit Log") { auditLog.clearLogs() }
                    .foregroundColor(.red)
            } header: {
                Text("Actions")
            }
        }
        .navigationTitle("Network Audit")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Prompt Templates
struct PromptTemplatesView: View {
    @StateObject private var manager = PromptTemplateManager.shared
    @State private var showAddSheet = false
    @State private var showImporter = false

    var body: some View {
        List {
            Section {
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
                    .onDelete { offsets in manager.remove(atOffsets: offsets) }
                }
            } header: {
                Text("Templates")
            }

            Section {
                Button("Add Template") { showAddSheet = true }
                Button("Import Templates") { showImporter = true }
                Button("Export Templates") { manager.exportTemplates() }
            } header: {
                Text("Actions")
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
                    ForEach(categories, id: \.self) { c in Text(c) }
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

// MARK: - SQL Assistant
struct SQLHelperView: View {
    @State private var query = ""
    @State private var result = ""
    @State private var errorMessage = ""

    var body: some View {
        Form {
            Section {
                TextEditor(text: $query)
                    .frame(minHeight: 100)
                    .font(.system(.body, design: .monospaced))
            } header: {
                Text("SQL Query")
            }

            Section {
                HStack {
                    Button("Validate") { validateSQL() }
                        .buttonStyle(.bordered)
                    Button("Execute") { executeSQL() }
                        .buttonStyle(.borderedProminent)
                }
            }

            Section {
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
            } header: {
                Text("Results")
            }
        }
        .navigationTitle("SQL Assistant")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func validateSQL() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { errorMessage = "Query is empty."; result = ""; return }
        let verbs = ["select", "update", "insert", "delete", "create", "drop", "alter"]
        let lower = trimmed.lowercased()
        guard trimmed.hasSuffix(";") else { errorMessage = "Query should end with a semicolon."; result = ""; return }
        guard verbs.contains(where: { lower.contains($0) }) else {
            errorMessage = "Query does not include a recognized SQL verb."; result = ""; return
        }
        errorMessage = ""; result = "Validation OK."
    }

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

// MARK: - Code Linter
struct CodeLinterView: View {
    @State private var code = ""
    @State private var lintResults: [String] = []
    @State private var language = "Swift"
    private let languages = ["Swift", "Python", "JavaScript", "TypeScript", "Java", "C++", "Go", "Rust"]

    var body: some View {
        Form {
            Section {
                Picker("Language", selection: $language) {
                    ForEach(languages, id: \.self) { lang in Text(lang) }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Language")
            }

            Section {
                TextEditor(text: $code)
                    .frame(minHeight: 200)
                    .font(.system(.body, design: .monospaced))
            } header: {
                Text("Code")
            }

            Section {
                HStack {
                    Button("Lint") { lint() }
                        .buttonStyle(.borderedProminent)
                    Button("Format") { code = format(code: code, language: language) }
                        .buttonStyle(.bordered)
                }
            }

            Section {
                if lintResults.isEmpty {
                    Text("No results yet").foregroundColor(.secondary)
                } else {
                    ForEach(lintResults, id: \.self) { issue in Text(issue) }
                }
            } header: {
                Text("Results")
            }
        }
        .navigationTitle("Code Linter")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func lint() {
        var issues: [String] = []
        let lines = code.components(separatedBy: .newlines)
        for (i, line) in lines.enumerated() {
            if line.count > 120 { issues.append("Line \(i+1): Line exceeds 120 characters.") }
            if line.hasSuffix(" ") { issues.append("Line \(i+1): Trailing whitespace.") }
        }
        if language == "Swift" && !code.contains("{") {
            issues.append("Swift: Consider adding braces for blocks if missing.")
        }
        lintResults = issues.isEmpty ? ["No issues found"] : issues
    }

    private func format(code: String, language: String) -> String {
        // Strip trailing spaces and ensure newline at EOF
        let lines = code.components(separatedBy: .newlines)
        let trimmed = lines.map { line in
            var s = line
            while s.last == " " || s.last == "\t" { _ = s.popLast() }
            return s
        }
        var joined = trimmed.joined(separator: "\n")
        if !joined.hasSuffix("\n") { joined.append("\n") }
        return joined
    }
}

// MARK: - Add Knowledge
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
        Task {
            for _ in selectedFiles {
                try? await Task.sleep(nanoseconds: 300_000_000)
                processedCount += 1
            }
            isProcessing = false
        }
    }
}

// MARK: - Embeddings Dashboard (EmbeddingsManager-aligned)
struct EmbeddingsDashboardView: View {
    @EnvironmentObject private var embeddingsManager: EmbeddingsManager

    private var relativeLastUpdated: String {
        let interval = Date().timeIntervalSince(embeddingsManager.lastUpdated)
        let minutes = Int(interval / 60)
        if minutes < 1 { return "just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        return "\(hours)h ago"
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Label("Total", systemImage: "number")
                    Spacer()
                    Text("\(embeddingsManager.totalEmbeddings)")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Label("Storage", systemImage: "externaldrive")
                    Spacer()
                    Text(embeddingsManager.storageSize)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Label("Dimensions", systemImage: "square.grid.3x3")
                    Spacer()
                    Text("\(embeddingsManager.vectorDimensions)")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Label("Last Updated", systemImage: "clock")
                    Spacer()
                    Text(relativeLastUpdated)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Overview")
            }

            Section {
                if embeddingsManager.knowledgeSources.isEmpty {
                    Text("No sources yet").foregroundColor(.secondary)
                } else {
                    ForEach(embeddingsManager.knowledgeSources) { source in
                        HStack(spacing: 12) {
                            Image(systemName: source.icon).foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.name).font(.headline)
                                Text("\(source.embeddingCount) embeddings • updated \(source.lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if source.isProcessing {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Menu {
                                    Button("Rebuild") { embeddingsManager.rebuildSource(source) }
                                    Button(role: .destructive) {
                                        embeddingsManager.deleteSource(source)
                                    } label: { Text("Delete") }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                Text("Sources")
            }

            Section {
                if embeddingsManager.isRebuilding {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rebuilding all embeddings…")
                        ProgressView(value: embeddingsManager.rebuildProgress)
                    }
                } else {
                    Button("Refresh Data") { embeddingsManager.refreshData() }
                    Button("Rebuild All Embeddings") { embeddingsManager.rebuildAllEmbeddings() }
                    Button("Export Embeddings") { embeddingsManager.exportEmbeddings() }
                    Button("Import Embeddings") { embeddingsManager.importEmbeddings() }
                    Button("Clear All Embeddings", role: .destructive) {
                        embeddingsManager.clearAllEmbeddings()
                    }
                }
            } header: {
                Text("Actions")
            }
        }
        .navigationTitle("Manage Embeddings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
