import SwiftUI

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

struct LintIssue: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let severity: LintSeverity
    let line: Int
    let suggestion: String?
}

@MainActor
final class CodeLinter: ObservableObject {
    @Published var lintIssues: [LintIssue] = []
    @Published var isLinting = false

    func lintCode(_ code: String, language: String) {
        isLinting = true
        lintIssues = []
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            Task { @MainActor in
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
