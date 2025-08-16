import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var modelRuntime: ModelRuntime
    @EnvironmentObject private var networkGuard: NetworkGuard
    @EnvironmentObject private var auditLog: AuditLog
    @EnvironmentObject private var knowledgeManager: KnowledgeManager
    @EnvironmentObject private var embeddingsManager: EmbeddingsManager

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // MARK: AI Model
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

                // MARK: Network Modes
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

                // MARK: Privacy & Security
                Section(header: Text("Privacy & Security")) {
                    NavigationLink("Network Audit Log") {
                        NetworkAuditView()
                    }
                    Button("Clear All Data") {
                        clearAllData()
                    }
                    .foregroundColor(.red)
                }

                // MARK: Data Engineering
                Section(header: Text("Data Engineering")) {
                    NavigationLink("Prompt Templates") { PromptTemplatesView() }
                    NavigationLink("SQL Assistant") { SQLHelperView() }
                    NavigationLink("Code Linter") { CodeLinterView() }
                }

                // MARK: Local Learning
                Section(header: Text("Local Learning")) {
                    NavigationLink("Add Knowledge") { AddKnowledgeView() }
                    NavigationLink("Manage Embeddings") { EmbeddingsView() }
                }

                // MARK: About
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
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    // MARK: Helpers

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

// MARK: - Network Audit

struct NetworkAuditView: View {
    @EnvironmentObject private var auditLog: AuditLog

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Recent Network Activity")) {
                    Text("No audit entries yet")
                        .foregroundColor(.secondary)
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
                                Text(template.name).font(.headline)
                                Spacer()
                                Button("Use") { templateManager.useTemplate(template) }
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
                    Button("Add New Template") { showingAddTemplate = true }
                    Button("Import Templates") { showingImportPicker = true }
                    Button("Export Templates") { templateManager.exportTemplates() }
                }
            }
            .navigationTitle("Prompt Templates")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddTemplate) { AddTemplateView() }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: allowedTemplateTypes,
                allowsMultipleSelection: false
            ) { result in
                templateManager.importTemplates(from: result)
            }
        }
    }

    private var allowedTemplateTypes: [UTType] {
        var types: [UTType] = [.json, .text]
        types.append(UTType(importedAs: "net.daringfireball.markdown"))
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
                        Text("Template Content").font(.headline)
                        TextEditor(text: $templateContent).frame(minHeight: 150)
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
                    Text("SQL Query").font(.headline)
                    TextEditor(text: $queryText)
                        .border(Color.gray, width: 1)
                        .frame(minHeight: 100)
                        .font(.system(.body, design: .monospaced))
                }

                HStack(spacing: 12) {
                    Button("Execute Query") { sqlHelper.executeQuery(queryText) }
                        .buttonStyle(.borderedProminent)
                        .disabled(queryText.isEmpty)

                    Button("Validate") { sqlHelper.validateQuery(queryText) }
                        .buttonStyle(.bordered)
                        .disabled(queryText.isEmpty)

                    Button("Format") { queryText = sqlHelper.formatQuery(queryText) }
                        .buttonStyle(.bordered)
                        .disabled(queryText.isEmpty)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Results").font(.headline)
                        if sqlHelper.isExecuting { ProgressView().scaleEffect(0.8) }
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
                                Text("No results yet").foregroundColor(.secondary)
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
                        Text("Language").font(.headline)
                        Spacer()
                        Picker("Language", selection: $selectedLanguage) {
                            ForEach(languages, id: \.self) { language in
                                Text(language).tag(language)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Text("Code").font(.headline)
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
                        Text("Lint Results").font(.headline)
                        if codeLinter.isLinting { ProgressView().scaleEffect(0.8) }
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            if codeLinter.lintIssues.isEmpty && !codeLinter.isLinting {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("No issues found").foregroundColor(.green)
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
                                            Text(issue.title).font(.headline)
                                            Spacer()
                                            Text("Line \(issue.line)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Text(issue.message)
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
    @EnvironmentObject private var knowledgeManager: KnowledgeManager
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
                    Button("Select Documents") { showingDocumentPicker = true }
                        .buttonStyle(.borderedProminent)

                    Button("Scan Document with Camera") { showingCameraScanner = true }
                        .buttonStyle(.bordered)

                    Button("Import from iCloud") { showingCloudImporter = true }
                        .buttonStyle(.bordered)
                }

                if !knowledgeManager.selectedDocuments.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Selected Documents").font(.headline)

                        ScrollView {
                            ForEach(knowledgeManager.selectedDocuments, id: \.id) { doc in
                                HStack {
                                    Image(systemName: doc.icon).foregroundColor(.blue)
                                    VStack(alignment: .leading) {
                                        Text(doc.name).font(.headline)
                                        Text("\(doc.size) • \(doc.type)")
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if doc.isProcessing {
                                        ProgressView().scaleEffect(0.8)
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
                            Button("Process Documents") { knowledgeManager.processDocuments() }
                                .buttonStyle(.borderedProminent)
                                .disabled(knowledgeManager.isProcessing)

                            Button("Clear Selection") { knowledgeManager.clearSelection() }
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
        var types: [UTType] = [.pdf, .text, .rtf, .plainText]
        types.append(UTType(importedAs: "net.daringfireball.markdown"))
        return types
    }
}

struct DocumentScannerView: View {
    let onDocumentsScanned: ([KnowledgeDocument]) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                Text("Document Scanner").font(.title)
                Text("Camera-based document scanning coming soon").foregroundColor(.secondary)
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
                Text("iCloud Import").font(.title)
                Text("iCloud document import coming soon").foregroundColor(.secondary)
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
