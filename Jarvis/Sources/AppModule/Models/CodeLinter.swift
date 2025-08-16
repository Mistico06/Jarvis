import SwiftUI

// MARK: - Lint Severity and Issue Models

enum LintSeverity {
    case error
    case warning
    case info

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

struct LintIssue: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let severity: LintSeverity
    let line: Int
    let suggestion: String?
}

// MARK: - Linter

@MainActor
final class CodeLinter: ObservableObject {
    @Published var lintIssues: [LintIssue] = []
    @Published var isLinting: Bool = false

    func lintCode(_ code: String, language: String) {
        isLinting = true
        lintIssues = []

        // Simulate async linting work
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [code, language] in
            Task { @MainActor in
                self.lintIssues = self.generateLintIssues(for: code, language: language)
                self.isLinting = false
            }
        }
    }

    func autoFixCode(_ code: String, language: String) -> String {
        var fixed = code
        // Simple whitespace cleanup
        fixed = fixed.replacingOccurrences(of: "  ", with: " ")
        fixed = fixed.replacingOccurrences(of: " )", with: ")")
        fixed = fixed.replacingOccurrences(of: "( ", with: "(")
        return fixed
    }

    func formatCode(_ code: String, language: String) -> String {
        switch language {
        case "Swift":
            return formatSwift(code)
        case "Python":
            return formatPython(code)
        case "JavaScript", "TypeScript":
            return formatJavaScript(code)
        default:
            return code
        }
    }

    // MARK: - Language-specific formatters (very lightweight)

    private func formatSwift(_ code: String) -> String {
        return code
            .replacingOccurrences(of: "{", with: " {\n")
            .replacingOccurrences(of: "}", with: "\n}")
            .replacingOccurrences(of: ";", with: ";\n")
    }

    private func formatPython(_ code: String) -> String {
        return code
            .replacingOccurrences(of: ":", with: ":\n")
    }

    private func formatJavaScript(_ code: String) -> String {
        return code
            .replacingOccurrences(of: "{", with: " {\n")
            .replacingOccurrences(of: "}", with: "\n}")
            .replacingOccurrences(of: ";", with: ";\n")
    }

    // MARK: - Issue generation (toy rules, illustrative only)

    private func generateLintIssues(for code: String, language: String) -> [LintIssue] {
        var issues: [LintIssue] = []
        let lines = code.components(separatedBy: .newlines)

        for (index, rawLine) in lines.enumerated() {
            let lineNumber = index + 1
            let line = rawLine

            // 1) Overly long line
            if line.count > 100 {
                issues.append(LintIssue(
                    title: "Line too long",
                    message: "Line exceeds 100 characters (\(line.count) characters).",
                    severity: .warning,
                    line: lineNumber,
                    suggestion: "Break the line into multiple statements."
                ))
            }

            // 2) Trailing whitespace line
            if line.trimmingCharacters(in: .whitespaces).isEmpty && line.count > 0 {
                issues.append(LintIssue(
                    title: "Trailing whitespace",
                    message: "Line contains only whitespace.",
                    severity: .info,
                    line: lineNumber,
                    suggestion: "Remove trailing or empty whitespace lines."
                ))
            }

            // 3) Simple language-specific checks
            switch language {
            case "Swift":
                // Suggest explicit access modifiers for vars
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("var ")
                    && !trimmed.hasPrefix("private ")
                    && !trimmed.hasPrefix("public ")
                    && !trimmed.hasPrefix("internal ") {
                    issues.append(LintIssue(
                        title: "Missing access modifier",
                        message: "Consider adding an explicit access modifier to 'var'.",
                        severity: .info,
                        line: lineNumber,
                        suggestion: "Add private, internal, or public."
                    ))
                }
            case "Python":
                // Very rough indent hint for function definitions
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("def ") && !line.hasPrefix("    ") {
                    issues.append(LintIssue(
                        title: "Function not indented",
                        message: "Function should be properly indented.",
                        severity: .error,
                        line: lineNumber,
                        suggestion: "Indent the function body appropriately."
                    ))
                }
            default:
                break
            }
        }

        return issues
    }
}
