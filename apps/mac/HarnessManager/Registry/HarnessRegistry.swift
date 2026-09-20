import Foundation

enum HarnessRegistry {
    static let all: [HarnessDefinition] = [
        ClaudeCodeDefinition.definition,
        CodexDefinition.definition,
        GeminiCLIDefinition.definition,
        OpenCodeDefinition.definition,
        CursorDefinition.definition,
        WarpDefinition.definition,
        MetaHarnessDefinitions.cmux,
        MetaHarnessDefinitions.orca,
        MetaHarnessDefinitions.herdr,
        MetaHarnessDefinitions.t3_code,
        MetaHarnessDefinitions.conductor,
        MetaHarnessDefinitions.superset,
        MetaHarnessDefinitions.paseo,
        MetaHarnessDefinitions.emdash,
        PlaceholderDefinitions.hermes,
        PlaceholderDefinitions.kiro,
        PlaceholderDefinitions.zcode,
        AntigravityDefinition.definition,
        AntigravityIDEDefinition.definition,
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
