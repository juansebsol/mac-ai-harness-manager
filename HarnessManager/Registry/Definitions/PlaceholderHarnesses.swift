import Foundation

/// Placeholder definitions for harnesses without reliable public detection metadata yet.
/// Marked incomplete so the scanner does not invent commands.
enum PlaceholderDefinitions {
    static let t3Code = placeholder(
        id: "t3-code",
        name: "T3 Code",
        website: "https://create.t3.gg",
        notes: "Detection metadata incomplete — binary names and install sources not yet confirmed."
    )

    static let conductor = placeholder(
        id: "conductor",
        name: "Conductor",
        notes: "Detection metadata incomplete."
    )

    static let superset = placeholder(
        id: "superset",
        name: "Superset",
        notes: "Detection metadata incomplete — not to be confused with Apache Superset."
    )

    static let paseo = placeholder(
        id: "paseo",
        name: "Paseo",
        notes: "Detection metadata incomplete."
    )

    static let emdash = placeholder(
        id: "emdash",
        name: "Emdash",
        notes: "Detection metadata incomplete."
    )

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

    static let antigravity = placeholder(
        id: "antigravity",
        name: "Antigravity",
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
