import Foundation

struct ConfigPathSpec: Codable, Hashable, Sendable {
    let path: String
    let label: String
    let kind: Kind

    enum Kind: String, Codable, Sendable {
        case directory
        case file
        case glob
    }

    /// Expand `~` and return an absolute URL. Does not create anything.
    func expandedURL(relativeTo home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        if path.hasPrefix("~/") {
            return home.appendingPathComponent(String(path.dropFirst(2)))
        }
        if path == "~" {
            return home
        }
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }
}

struct HarnessDefinition: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let binaryNames: [String]
    let applicationBundleIdentifiers: [String]
    let configPaths: [ConfigPathSpec]
    let versionArguments: [String]
    let installationMethods: [InstallationMethod]
    let providerIds: [String]
    let website: URL?
    let iconName: String?
    /// When false, detection is intentionally incomplete — do not invent commands.
    let isComplete: Bool
    let notes: String?

    init(
        id: String,
        name: String,
        binaryNames: [String] = [],
        applicationBundleIdentifiers: [String] = [],
        configPaths: [ConfigPathSpec] = [],
        versionArguments: [String] = ["--version"],
        installationMethods: [InstallationMethod] = [],
        providerIds: [String] = [],
        website: URL? = nil,
        iconName: String? = nil,
        isComplete: Bool = true,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.binaryNames = binaryNames
        self.applicationBundleIdentifiers = applicationBundleIdentifiers
        self.configPaths = configPaths
        self.versionArguments = versionArguments
        self.installationMethods = installationMethods
        self.providerIds = providerIds
        self.website = website
        self.iconName = iconName
        self.isComplete = isComplete
        self.notes = notes
    }
}
