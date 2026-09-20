import Foundation

enum DiagnosticSeverity: String, Codable, Hashable, Sendable {
    case pass
    case warning
    case error
    case informational

    var symbolName: String {
        switch self {
        case .pass: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .informational: return "info.circle.fill"
        }
    }
}

struct DiagnosticResult: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let severity: DiagnosticSeverity
    let message: String

    init(id: UUID = UUID(), name: String, severity: DiagnosticSeverity, message: String) {
        self.id = id
        self.name = name
        self.severity = severity
        self.message = message
    }
}

protocol DiagnosticCheck: Sendable {
    var name: String { get }
    func run() async -> DiagnosticResult
}
