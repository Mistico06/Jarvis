import Foundation
import UIKit

struct PromptTemplate: Codable, Identifiable, Equatable {
    var id = UUID()
    let name: String
    let content: String
    let category: String
}

@MainActor
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
