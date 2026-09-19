import Foundation

enum HarnessRegistry {
    static let all: [HarnessDefinition] = [
        ClaudeCodeDefinition.definition,
        CodexDefinition.definition,
        GeminiCLIDefinition.definition,
        OpenCodeDefinition.definition,
        CursorDefinition.definition,
        WarpDefinition.definition,
        PlaceholderDefinitions.t3Code,
        PlaceholderDefinitions.conductor,
        PlaceholderDefinitions.superset,
        PlaceholderDefinitions.paseo,
        PlaceholderDefinitions.emdash,
        PlaceholderDefinitions.hermes,
        PlaceholderDefinitions.kiro,
        PlaceholderDefinitions.zcode,
        PlaceholderDefinitions.antigravity,
        PlaceholderDefinitions.openChamber,
        PlaceholderDefinitions.vibeKanban
    ]

    static func definition(for id: String) -> HarnessDefinition? {
        all.first { $0.id == id }
    }

    static var complete: [HarnessDefinition] {
        all.filter(\.isComplete)
    }

    static var incomplete: [HarnessDefinition] {
        all.filter { !$0.isComplete }
    }
}
