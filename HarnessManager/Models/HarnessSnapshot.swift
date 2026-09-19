import Foundation

struct DiscoveredConfig: Identifiable, Codable, Hashable, Sendable {
    var id: String { "\(label):\(path)" }
    let label: String
    let path: String
    let exists: Bool
    let kind: ConfigPathSpec.Kind
}

struct HarnessSnapshot: Identifiable, Codable, Hashable, Sendable {
    let definitionId: String
    var name: String
    var status: HarnessStatus
    var installedVersion: String?
    var latestVersion: String?
    var updateStatus: UpdateStatus
    var installSource: DetectedInstallSource
    var binaryPath: String?
    var applicationPath: String?
    var providerIds: [String]
    var activeProject: String?
    var configItems: [DiscoveredConfig]
    var processCount: Int
    var isInstalled: Bool
    var lastScannedAt: Date
    var definitionIncomplete: Bool

    var id: String { definitionId }

    var displayVersion: String {
        installedVersion ?? "—"
    }

    var displayProvider: String {
        guard !providerIds.isEmpty else { return "—" }
        return providerIds
            .map { ProviderCatalog.displayName(for: $0) }
            .joined(separator: ", ")
    }

    var displayInstallMethod: String {
        installSource.displayName
    }

    var displayActiveProject: String {
        activeProject ?? "—"
    }
}

struct HarnessSummary: Sendable {
    var installed: Int
    var running: Int
    var updates: Int
    var issues: Int
}
