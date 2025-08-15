import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

// MARK: - Data Models Shared In This File

struct NetworkLog: Identifiable {
    let id = UUID()
    let host: String
    let path: String
    let method: String
    let purpose: String
    let timestamp: Date
    let isSuccess: Bool
}

enum LintSeverity {
    case error, warning, info

    var color: Color {
        switch self {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }

    var iconName: String {
        switch self {
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

struct LintIssue: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let severity: LintSeverity
    let line: Int
    let suggestion: String?

    init(title: String, message: String, severity: LintSeverity, line: Int, suggestion: String? = nil) {
        self.title = title
        self.message = message
        self.severity = severity
        self.line = line
        self.suggestion = suggestion
    }
}

struct PromptTemplate: Codable, Identifiable {
    var id = UUID() // var to avoid decoding warning
    let name: String
    let content: String
    let category: String
}

struct KnowledgeDocument: Identifiable {
    let id = UUID()
    let name: String
    let size: String
    let type: String
    let url: URL?
    var isProcessing = false
    var isProcessed = false

    var icon: String {
        switch type.lowercased() {
        case "pdf": return "doc.text.fill"
        case "txt", "md": return "doc.plaintext.fill"
        case "rtf": return "doc.richtext.fill"
        default: return "doc.fill"
        }
    }

    init(name: String, size: String, type: String, url: URL? = nil) {
        self.name = name
        self.size = size
        self.type = type
        self.url = url
    }
}

struct KnowledgeSource: Identifiable {
    let id = UUID()
    let name: String
    let embeddingCount: Int
    var lastUpdated: Date  // var so we can mutate it
    var isProcessing = false

    var icon: String {
        switch name.lowercased() {
        case let n where n.contains("swift"): return "swift"
        case let n where n.contains("ios"): return "apple.logo"
        case let n where n.contains("machine"), let n where n.contains("ml"): return "brain.head.profile"
        default: return "doc.text.fill"
        }
    }
}

// Mock data
enum MockData {
    static let networkLogs: [NetworkLog] = [
        NetworkLog(host: "api.openai.com", path: "/v1/chat/completions", method: "POST", purpose: "Chat completion", timestamp: Date().addingTimeInterval(-120), isSuccess: true),
        NetworkLog(host: "api.anthropic.com", path: "/v1/messages", method: "POST", purpose: "Claude API", timestamp: Date().addingTimeInterval(-300), isSuccess: true),
        NetworkLog(host: "huggingface.co", path: "/api/models", method: "GET", purpose: "Model search", timestamp: Date().addingTimeInterval(-450), isSuccess: false),
        NetworkLog(host: "api.together.xyz", path: "/inference", method: "POST", purpose: "Inference request", timestamp: Date().addingTimeInterval(-600), isSuccess: true)
    ]
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var modelRuntime: ModelRuntime
    @EnvironmentObject private var networkGuard: NetworkGuard
    @StateObject private var auditLog = AuditLog.shared

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("AI Model")) {
                    Picker("Model Size", selection: $appState.selectedModel) {
                        Text("Lite (3B) – Faster").tag(ModelRuntime.ModelSize.lite)
                        Text("Max (4B) – Smarter").tag(ModelRuntime.ModelSize.max)
                    }
                    .onChange(of: appState.selectedModel) { newModel in
                        Task { await modelRuntime.switchModel(to: newModel) }
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

                Section(header: Text("Privacy & Security")) {
                    NavigationLink("Network Audit Log") {
                        NetworkAuditView()
                            .environmentObject(auditLog)
                    }
                    Button("Clear All Data") {
                        clearAllData()
                    }
                    .foregroundColor(.red)
                }

                Section(header: Text("Data Engineering")) {
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

                Section(header: Text("Local Learning")) {
                    NavigationLink("Add Knowledge") {
                        AddKnowledgeView()
                    }
                    NavigationLink("Manage Embeddings") {
                        EmbeddingsView()
                    }
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
        ConversationStore.shared.clear()
        auditLog.clearLogs()
        // If LocalEmbeddings is available, uncomment the next line
        // LocalEmbeddings.shared.clearCache()
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

// MARK: - Network Audit

struct NetworkAuditView: View {
    @EnvironmentObject private var auditLog: AuditLog

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Recent Network Activity")) {
                    ForEach(MockData.networkLogs, id: \.id) { log in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: log.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(log.isSuccess ? .green : .red)
                                Text(log.host)
                                    .font(.headline)
                                Spacer()
                                Text(log.timestamp, style: .relative)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text("\(log.method) \(log.path)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if !log.purpose.isEmpty {
                                Text("Purpose: \(log.purpose)")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section(header: Text("Settings")) {
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
}

// MARK: - Prompt Templates

struct PromptTemplatesView: View {
    @StateObject private var templateManager = PromptTemplateManager.shared
    @State private var showingAddTemplate = false
    @State private var showingImportPicker = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Available Templates")) {
                    ForEach(templateManager.templates, id: \.id) { template in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(template.name)
                                    .font(.headline)
                                Spacer()
                                Button("Use") {
                                    templateManager.useTemplate(template)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            Text(template.content)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 2)
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                templateManager.deleteTemplate(template)
                            }
                        }
                    }
                }

                Section(header: Text("Actions")) {
                    Button("Add New Template") {
                        showingAddTemplate = true
                    }
                    Button("Import Templates") {
                        showingImportPicker = true
                    }
                    Button("Export Templates") {
                        templateManager.exportTemplates()
                    }
                }
            }
            .navigationTitle("Prompt Templates")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddTemplate) {
                AddTemplateView()
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: allowedTemplateTypes,
                allowsMultipleSelection: false
            ) { result in
                templateManager.importTemplates(from: result)
            }
        }
    }

    // Replace unavailable UTType.markdown with imported type
    private var allowedTemplateTypes: [UTType] {
        var types: [UTType] = [.json, .text]
        let markdown = UTType(importedAs: "net.daringfireball.markdown")
        types.append(markdown)
        return types
    }
}

struct AddTemplateView: View {
    @StateObject private var templateManager = PromptTemplateManager.shared
    @State private var templateName = ""
    @State private var templateContent = ""
    @State private var templateCategory = "General"
    @Environment(\.dismiss) private var dismiss

    let categories = ["General", "Code Review", "Documentation", "SQL", "Analysis", "Creative"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Template Details")) {
                    TextField("Template Name", text: $templateName)

                    Picker("Category", selection: $templateCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("Template Content")
                            .font(.headline)
                        TextEditor(text: $templateContent)
                            .frame(minHeight: 150)
                    }
                }
            }
            .navigationTitle("Add Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        templateManager.addTemplate(
                            name: templateName,
                            content: templateContent,
                            category: templateCategory
                        )
                        dismiss()
                    }
                    .disabled(templateName.isEmpty || templateContent.isEmpty)
                }
            }
        }
    }
}

// MARK: - SQL Helper

struct SQLHelperView: View {
    @StateObject private var sqlHelper = SQLHelper()
    @State private var queryText = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SQL Query")
                        .font(.headline)
                    TextEditor(text: $queryText)
                        .border(Color.gray, width: 1)
                        .frame(minHeight: 100)
                        .font(.system(.body, design: .monospaced))
                }

                HStack(spacing: 12) {
                    Button("Execute Query") {
                        sqlHelper.executeQuery(queryText)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(queryText.isEmpty)

                    Button("Validate") {
                        sqlHelper.validateQuery(queryText)
                    }
                    .buttonStyle(.bordered)
                    .disabled(queryText.isEmpty)

                    Button("Format") {
                        queryText = sqlHelper.formatQuery(queryText)
                    }
                    .buttonStyle(.bordered)
                    .disabled(queryText.isEmpty)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Results")
                            .font(.headline)
                        if sqlHelper.isExecuting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            if !sqlHelper.errorMessage.isEmpty {
                                Text(sqlHelper.errorMessage)
                                    .foregroundColor(.red)
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                            }

                            if !sqlHelper.results.isEmpty {
                                ForEach(sqlHelper.results, id: \.self) { row in
                                    Text(row)
                                        .font(.system(.caption, design: .monospaced))
                                        .padding(.vertical, 2)
                                }
                            } else if !sqlHelper.isExecuting && sqlHelper.errorMessage.isEmpty {
                                Text("No results yet")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .frame(minHeight: 200)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("SQL Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu("Examples") {
                        Button("SELECT Query") {
                            queryText = "SELECT * FROM users WHERE active = 1;"
                        }
                        Button("JOIN Query") {
                            queryText = "SELECT u.name, p.title FROM users u JOIN posts p ON u.id = p.user_id;"
                        }
                        Button("CREATE TABLE") {
                            queryText = "CREATE TABLE users (\n  id INTEGER PRIMARY KEY,\n  name TEXT NOT NULL,\n  email TEXT UNIQUE\n);"
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Code Linter

struct CodeLinterView: View {
    @StateObject private var codeLinter = CodeLinter()
    @State private var codeText = ""
    @State private var selectedLanguage = "Swift"

    let languages = ["Swift", "Python", "JavaScript", "TypeScript", "Java", "C++", "Go", "Rust"]

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Language")
                            .font(.headline)
                        Spacer()
                        Picker("Language", selection: $selectedLanguage) {
                            ForEach(languages, id: \.self) { language in
                                Text(language).tag(language)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Text("Code")
                        .font(.headline)
                    TextEditor(text: $codeText)
                        .border(Color.gray, width: 1)
                        .frame(minHeight: 150)
                        .font(.system(.body, design: .monospaced))
                }

                HStack(spacing: 12) {
                    Button("Lint Code") {
                        codeLinter.lintCode(codeText, language: selectedLanguage)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(codeText.isEmpty)

                    Button("Auto-Fix") {
                        codeText = codeLinter.autoFixCode(codeText, language: selectedLanguage)
                    }
                    .buttonStyle(.bordered)
                    .disabled(codeText.isEmpty)

                    Button("Format") {
                        codeText = codeLinter.formatCode(codeText, language: selectedLanguage)
                    }
                    .buttonStyle(.bordered)
                    .disabled(codeText.isEmpty)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Lint Results")
                            .font(.headline)
                        if codeLinter.isLinting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            if codeLinter.lintIssues.isEmpty && !codeLinter.isLinting {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("No issues found")
                                        .foregroundColor(.green)
                                }
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                            } else {
                                ForEach(codeLinter.lintIssues, id: \.id) { issue in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Image(systemName: issue.severity.iconName)
                                                .foregroundColor(issue.severity.color)
                                            Text(issue.title)
                                                .font(.headline)
                                            Spacer()
                                            Text("Line \(issue.line)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Text(issue.message)
                                            .font(.body)
                                        if let suggestion = issue.suggestion {
                                            Text("Suggestion: \(suggestion)")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding()
                                    .background(issue.severity.color.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 200)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Code Linter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu("Examples") {
                        Button("Swift Example") {
                            codeText = """
                            func calculateArea(radius: Double) -> Double {
                                let pi = 3.14159
                                return pi * radius * radius
                            }
                            """
                            selectedLanguage = "Swift"
                        }
                        Button("Python Example") {
                            codeText = """
                            def calculate_area(radius):
                                pi = 3.14159
                                return pi * radius ** 2
                            """
                            selectedLanguage = "Python"
                        }
                        Button("JavaScript Example") {
                            codeText = """
                            function calculateArea(radius) {
                                const pi = 3.14159;
                                return pi * radius * radius;
                            }
                            """
                            selectedLanguage = "JavaScript"
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Add Knowledge

struct AddKnowledgeView: View {
    @StateObject private var knowledgeManager = KnowledgeManager.shared
    @State private var showingDocumentPicker = false
    @State private var showingCameraScanner = false
    @State private var showingCloudImporter = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Add Knowledge to Jarvis")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Upload documents, PDFs, and text files to enhance Jarvis's knowledge base")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 12) {
                    Button("Select Documents") {
                        showingDocumentPicker = true
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Scan Document with Camera") {
                        showingCameraScanner = true
                    }
                    .buttonStyle(.bordered)

                    Button("Import from iCloud") {
                        showingCloudImporter = true
                    }
                    .buttonStyle(.bordered)
                }

                if !knowledgeManager.selectedDocuments.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Selected Documents")
                            .font(.headline)

                        ScrollView {
                            ForEach(knowledgeManager.selectedDocuments, id: \.id) { doc in
                                HStack {
                                    Image(systemName: doc.icon)
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading) {
                                        Text(doc.name)
                                            .font(.headline)
                                        Text("\(doc.size) • \(doc.type)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if doc.isProcessing {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else if doc.isProcessed {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .frame(maxHeight: 200)

                        HStack(spacing: 12) {
                            Button("Process Documents") {
                                knowledgeManager.processDocuments()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(knowledgeManager.isProcessing)

                            Button("Clear Selection") {
                                knowledgeManager.clearSelection()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                if knowledgeManager.isProcessing {
                    VStack(spacing: 8) {
                        ProgressView("Processing documents...")
                        Text("\(knowledgeManager.processedCount)/\(knowledgeManager.selectedDocuments.count) completed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Add Knowledge")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $showingDocumentPicker,
                allowedContentTypes: allowedDocTypes,
                allowsMultipleSelection: true
            ) { result in
                knowledgeManager.handleDocumentSelection(result)
            }
            .sheet(isPresented: $showingCameraScanner) {
                DocumentScannerView { scannedDocuments in
                    knowledgeManager.addScannedDocuments(scannedDocuments)
                }
            }
            .sheet(isPresented: $showingCloudImporter) {
                CloudImporterView { cloudDocuments in
                    knowledgeManager.addCloudDocuments(cloudDocuments)
                }
            }
        }
    }

    private var allowedDocTypes: [UTType] {
        var types: [UTType] = [.pdf, .text, .rtf]
        types.append(UTType.plainText)
        let md = UTType(importedAs: "net.daringfireball.markdown")
        types.append(md)
        return types
    }
}

struct DocumentScannerView: View {
    let onDocumentsScanned: ([KnowledgeDocument]) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                Text("Document Scanner")
                    .font(.title)
                Text("Camera-based document scanning coming soon")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Scan Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct CloudImporterView: View {
    let onDocumentsImported: ([KnowledgeDocument]) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                Text("iCloud Import")
                    .font(.title)
                Text("iCloud document import coming soon")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Import from iCloud")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Embeddings

struct EmbeddingsView: View {
    @StateObject private var embeddingsManager = EmbeddingsManager.shared
    @State private var showingRebuildAlert = false
    @State private var showingClearAlert = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Statistics")) {
                    HStack {
                        Text("Total Embeddings")
                        Spacer()
                        Text("\(embeddingsManager.totalEmbeddings)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Storage Used")
                        Spacer()
                        Text(embeddingsManager.storageSize)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Last Updated")
                        Spacer()
                        Text(embeddingsManager.lastUpdated, style: .relative)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Vector Dimensions")
                        Spacer()
                        Text("\(embeddingsManager.vectorDimensions)")
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Knowledge Sources")) {
                    ForEach(embeddingsManager.knowledgeSources, id: \.id) { source in
                        HStack {
                            Image(systemName: source.icon)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(source.name)
                                    .font(.headline)
                                Text("\(source.embeddingCount) embeddings • \(source.lastUpdated, style: .relative)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if source.isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding(.vertical, 2)
                        .swipeActions {
                            Button("Rebuild") {
                                embeddingsManager.rebuildSource(source)
                            }
                            .tint(.blue)

                            Button("Delete", role: .destructive) {
                                embeddingsManager.deleteSource(source)
                            }
                        }
                    }
                }

                Section(header: Text("Actions")) {
                    Button("Rebuild All Embeddings") {
                        showingRebuildAlert = true
                    }
                    .disabled(embeddingsManager.isRebuilding)

                    Button("Export Embeddings") {
                        embeddingsManager.exportEmbeddings()
                    }

                    Button("Import Embeddings") {
                        embeddingsManager.importEmbeddings()
                    }

                    Button("Clear All Embeddings") {
                        showingClearAlert = true
                    }
                    .foregroundColor(.red)
                }

                if embeddingsManager.isRebuilding {
                    Section(header: Text("Progress")) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Rebuilding embeddings...")
                                Spacer()
                                Text("\(Int(embeddingsManager.rebuildProgress * 100))%")
                            }
                            ProgressView(value: embeddingsManager.rebuildProgress)
                        }
                    }
                }
            }
            .navigationTitle("Embeddings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                embeddingsManager.refreshData()
            }
            .alert("Rebuild All Embeddings", isPresented: $showingRebuildAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Rebuild", role: .destructive) {
                    embeddingsManager.rebuildAllEmbeddings()
                }
            } message: {
                Text("This will rebuild all embeddings from your knowledge sources. This process may take several minutes.")
            }
            .alert("Clear All Embeddings", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    embeddingsManager.clearAllEmbeddings()
                }
            } message: {
                Text("This will permanently delete all embeddings. You'll need to rebuild them to use knowledge search.")
            }
        }
    }
}

final class EmbeddingsManager: ObservableObject {
    static let shared = EmbeddingsManager()

    @Published var totalEmbeddings = 1_247
    @Published var storageSize = "15.3 MB"
    @Published var lastUpdated = Date().addingTimeInterval(-7200) // 2 hours ago
    @Published var vectorDimensions = 768
    @Published var knowledgeSources: [KnowledgeSource] = []
    @Published var isRebuilding = false
    @Published var rebuildProgress: Double = 0.0

    private init() {
        loadKnowledgeSources()
    }

    func refreshData() {
        loadKnowledgeSources()
    }

    func rebuildAllEmbeddings() {
        isRebuilding = true
        rebuildProgress = 0.0

        Task {
            for i in 0..<100 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                await MainActor.run {
                    rebuildProgress = Double(i) / 100.0
                }
            }

            await MainActor.run {
                isRebuilding = false
                rebuildProgress = 1.0
                lastUpdated = Date()
            }
        }
    }

    func rebuildSource(_ source: KnowledgeSource) {
        if let index = knowledgeSources.firstIndex(where: { $0.id == source.id }) {
            knowledgeSources[index].isProcessing = true
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                await MainActor.run {
                    knowledgeSources[index].isProcessing = false
                    knowledgeSources[index].lastUpdated = Date()
                }
            }
        }
    }

    func deleteSource(_ source: KnowledgeSource) {
        knowledgeSources.removeAll { $0.id == source.id }
        totalEmbeddings -= source.embeddingCount
        updateStorageSize()
    }

    func exportEmbeddings() {
        // Export embeddings to file
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("embeddings_export.json")

        let exportData: [String: Any] = [
            "total_embeddings": totalEmbeddings,
            "vector_dimensions": vectorDimensions,
            "exported_at": ISO8601DateFormatter().string(from: Date())
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            try data.write(to: fileURL)
            print("Embeddings exported to: \(fileURL)")
        } catch {
            print("Export failed: \(error)")
        }
    }

    func importEmbeddings() {
        // Simulate import process
        print("Embedding import feature coming soon")
    }

    func clearAllEmbeddings() {
        totalEmbeddings = 0
        storageSize = "0 MB"
        knowledgeSources.removeAll()
        // If LocalEmbeddings is available, uncomment the next line
        // LocalEmbeddings.shared.clearCache()
    }

    private func loadKnowledgeSources() {
        knowledgeSources = [
            KnowledgeSource(name: "Swift Documentation", embeddingCount: 423, lastUpdated: Date().addingTimeInterval(-3600)),
            KnowledgeSource(name: "iOS Development Guide", embeddingCount: 312, lastUpdated: Date().addingTimeInterval(-7200)),
            KnowledgeSource(name: "Machine Learning Papers", embeddingCount: 289, lastUpdated: Date().addingTimeInterval(-10800)),
            KnowledgeSource(name: "Project Notes", embeddingCount: 223, lastUpdated: Date().addingTimeInterval(-14400))
        ]
    }

    private func updateStorageSize() {
        let sizeInMB = Double(totalEmbeddings) * 0.012 // Approximate size calculation
        storageSize = String(format: "%.1f MB", sizeInMB)
    }
}

// MARK: - Managers For Templates, SQL, Linting

final class PromptTemplateManager: ObservableObject {
    static let shared = PromptTemplateManager()

    @Published var templates: [PromptTemplate] = []

    private init() {
        loadTemplates()
    }

    private func loadTemplates() {
        templates = [
            PromptTemplate(name: "Code Review", content: "Please review the following code for bugs, performance issues, and best practices:", category: "Code Review"),
            PromptTemplate(name: "SQL Query", content: "Generate an SQL query to:", category: "SQL"),
            PromptTemplate(name: "Documentation", content: "Create comprehensive documentation for the following code:", category: "Documentation"),
            PromptTemplate(name: "Refactor", content: "Refactor this code to improve readability and performance:", category: "Code Review"),
            PromptTemplate(name: "Explain Code", content: "Explain what this code does in simple terms:", category: "General"),
            PromptTemplate(name: "Bug Analysis", content: "Analyze this code for potential bugs and security issues:", category: "Analysis")
        ]
    }

    func addTemplate(name: String, content: String, category: String) {
        let template = PromptTemplate(name: name, content: content, category: category)
        templates.append(template)
        saveTemplates()
    }

    func deleteTemplate(_ template: PromptTemplate) {
        templates.removeAll { $0.id == template.id }
        saveTemplates()
    }

    func useTemplate(_ template: PromptTemplate) {
        UIPasteboard.general.string = template.content
        print("Template '\(template.name)' copied to clipboard")
    }

    func exportTemplates() {
        do {
            let data = try JSONEncoder().encode(templates)
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent("prompt_templates.json")
            try data.write(to: fileURL)
            print("Templates exported to: \(fileURL)")
        } catch {
            print("Export failed: \(error)")
        }
    }

    func importTemplates(from result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let data = try Data(contentsOf: url)
                let importedTemplates = try JSONDecoder().decode([PromptTemplate].self, from: data)
                templates.append(contentsOf: importedTemplates)
                saveTemplates()
                print("Imported \(importedTemplates.count) templates")
            } catch {
                print("Import failed: \(error)")
            }
        case .failure(let error):
            print("File selection failed: \(error)")
        }
    }

    private func saveTemplates() {
        do {
            let data = try JSONEncoder().encode(templates)
            UserDefaults.standard.set(data, forKey: "prompt_templates")
        } catch {
            print("Save failed: \(error)")
        }
    }
}

final class SQLHelper: ObservableObject {
    @Published var results: [String] = []
    @Published var errorMessage = ""
    @Published var isExecuting = false

    func executeQuery(_ query: String) {
        isExecuting = true
        errorMessage = ""
        results = []
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            DispatchQueue.main.async {
                if query.lowercased().contains("select") {
                    self.results = [
                        "id | name | email",
                        "---|------|------",
                        "1  | John | john@example.com",
                        "2  | Jane | jane@example.com",
                        "3  | Bob  | bob@example.com"
                    ]
                } else if query.lowercased().contains("create") {
                    self.results = ["Table created successfully"]
                } else if query.lowercased().contains("insert") {
                    self.results = ["1 row inserted"]
                } else {
                    self.errorMessage = "Query type not supported in demo mode"
                }
                self.isExecuting = false
            }
        }
    }

    func validateQuery(_ query: String) {
        let keywords = ["select", "from", "where", "insert", "update", "delete", "create", "drop"]
        let hasKeyword = keywords.contains { query.lowercased().contains($0) }
        errorMessage = hasKeyword ? "" : "Query must contain valid SQL keywords"
    }

    func formatQuery(_ query: String) -> String {
        return query
            .replacingOccurrences(of: " select ", with: "\nSELECT ")
            .replacingOccurrences(of: " from ", with: "\nFROM ")
            .replacingOccurrences(of: " where ", with: "\nWHERE ")
            .replacingOccurrences(of: " and ", with: "\n  AND ")
            .replacingOccurrences(of: " or ", with: "\n  OR ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

final class CodeLinter: ObservableObject {
    @Published var lintIssues: [LintIssue] = []
    @Published var isLinting = false

    func lintCode(_ code: String, language: String) {
        isLinting = true
        lintIssues = []
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            DispatchQueue.main.async {
                self.lintIssues = self.generateLintIssues(for: code, language: language)
                self.isLinting = false
            }
        }
    }

    func autoFixCode(_ code: String, language: String) -> String {
        var fixedCode = code
        fixedCode = fixedCode.replacingOccurrences(of: "  ", with: " ")
        fixedCode = fixedCode.replacingOccurrences(of: " )", with: ")")
        fixedCode = fixedCode.replacingOccurrences(of: "( ", with: "(")
        return fixedCode
    }

    func formatCode(_ code: String, language: String) -> String {
        switch language {
        case "Swift":
            return formatSwiftCode(code)
        case "Python":
            return formatPythonCode(code)
        case "JavaScript", "TypeScript":
            return formatJavaScriptCode(code)
        default:
            return code
        }
    }

    private func formatSwiftCode(_ code: String) -> String {
        return code
            .replacingOccurrences(of: "{", with: " {\n")
            .replacingOccurrences(of: "}", with: "\n}")
            .replacingOccurrences(of: ";", with: ";\n")
    }

    private func formatPythonCode(_ code: String) -> String {
        return code
            .replacingOccurrences(of: ":", with: ":\n")
    }

    private func formatJavaScriptCode(_ code: String) -> String {
        return code
            .replacingOccurrences(of: "{", with: " {\n")
            .replacingOccurrences(of: "}", with: "\n}")
            .replacingOccurrences(of: ";", with: ";\n")
    }

    private func generateLintIssues(for code: String, language: String) -> [LintIssue] {
        var issues: [LintIssue] = []
        let lines = code.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            if line.count > 100 {
                issues.append(LintIssue(
                    title: "Line too long",
                    message: "Line exceeds 100 characters (\(line.count) characters)",
                    severity: .warning,
                    line: index + 1,
                    suggestion: "Consider breaking this line into multiple lines"
                ))
            }

            if line.trimmingCharacters(in: .whitespaces).isEmpty && line.count > 0 {
                issues.append(LintIssue(
                    title: "Trailing whitespace",
                    message: "Line contains only whitespace",
                    severity: .info,
                    line: index + 1,
                    suggestion: "Remove trailing whitespace"
                ))
            }

            switch language {
            case "Swift":
                if line.contains("var") && !line.contains("private") && !line.contains("public") {
                    issues.append(LintIssue(
                        title: "Missing access modifier",
                        message: "Consider adding an explicit access modifier",
                        severity: .info,
                        line: index + 1,
                        suggestion: "Add private, internal, or public"
                    ))
                }
            case "Python":
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("def ") && !line.hasPrefix("    ") {
                    issues.append(LintIssue(
                        title: "Function not indented",
                        message: "Function should be properly indented",
                        severity: .error,
                        line: index + 1,
                        suggestion: "Add proper indentation"
                    ))
                }
            default:
                break
            }
        }

        return issues
    }
}

final class KnowledgeManager: ObservableObject {
    static let shared = KnowledgeManager()

    @Published var selectedDocuments: [KnowledgeDocument] = []
    @Published var isProcessing = false
    @Published var processedCount = 0

    private init() {}

    func handleDocumentSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                let doc = KnowledgeDocument(
                    name: url.lastPathComponent,
                    size: formatFileSize(url),
                    type: url.pathExtension.uppercased(),
                    url: url
                )
                selectedDocuments.append(doc)
            }
        case .failure(let error):
            print("Document selection failed: \(error)")
        }
    }

    func addScannedDocuments(_ docs: [KnowledgeDocument]) {
        selectedDocuments.append(contentsOf: docs)
    }

    func addCloudDocuments(_ docs: [KnowledgeDocument]) {
        selectedDocuments.append(contentsOf: docs)
    }

    func processDocuments() {
        isProcessing = true
        processedCount = 0
        for (index, _) in selectedDocuments.enumerated() {
            selectedDocuments[index].isProcessing = true
        }
        Task {
            for (index, _) in selectedDocuments.enumerated() {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s per doc
                await MainActor.run {
                    selectedDocuments[index].isProcessing = false
                    selectedDocuments[index].isProcessed = true
                    processedCount += 1
                }
            }
            await MainActor.run {
                isProcessing = false
            }
        }
    }

    func clearSelection() {
        selectedDocuments.removeAll()
        processedCount = 0
        isProcessing = false
    }

    private func formatFileSize(_ url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else {
            return "0 KB"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
