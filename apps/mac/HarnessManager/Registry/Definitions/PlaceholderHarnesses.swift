import Foundation

/// Placeholder definitions for harnesses without reliable public detection metadata yet.
/// Marked incomplete so the scanner does not invent commands.
enum PlaceholderDefinitions {
    static let hermes = placeholder(
        id: "hermes",
        name: "Hermes",
        notes: "Detection metadata incomplete."
    )

    static let kiro = placeholder(
        id: "kiro",
        name: "Kiro",
        website: "https://kiro.dev",
        binaryNames: ["kiro"],
        applicationBundleIdentifiers: ["dev.kiro.desktop"],
        notes: "Partial — application/CLI detection may improve as public install paths stabilize.",
        isComplete: false
    )

    static let zcode = placeholder(
        id: "zcode",
        name: "ZCode",
        notes: "Detection metadata incomplete."
    )

    static let openChamber = placeholder(
        id: "openchamber",
        name: "OpenChamber",
        notes: "Detection metadata incomplete."
    )

    static let vibeKanban = placeholder(
        id: "vibe-kanban",
        name: "Vibe Kanban",
        notes: "Detection metadata incomplete."
    )

    private static func placeholder(
        id: String,
        name: String,
        website: String? = nil,
        binaryNames: [String] = [],
        applicationBundleIdentifiers: [String] = [],
        notes: String,
        isComplete: Bool = false
    ) -> HarnessDefinition {
        HarnessDefinition(
            id: id,
            name: name,
            binaryNames: binaryNames,
            applicationBundleIdentifiers: applicationBundleIdentifiers,
            configPaths: [],
            versionArguments: ["--version"],
            installationMethods: [],
            providerIds: [],
            website: website.flatMap(URL.init(string:)),
            iconName: "questionmark.app",
            isComplete: isComplete,
            notes: notes
        )
    }
}
