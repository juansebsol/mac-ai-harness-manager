import Foundation

enum PreferredTerminal: String, Codable, CaseIterable, Identifiable, Sendable {
    case automatic
    case terminal
    case iterm
    case warp
    case ghostty

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .terminal: return "Terminal"
        case .iterm: return "iTerm"
        case .warp: return "Warp"
        case .ghostty: return "Ghostty"
        }
    }
}

struct AppSettings: Codable, Hashable, Sendable {
    var hasCompletedOnboarding: Bool = false
    var launchAtLogin: Bool = false
    /// Off by default — avoids background scans competing with the UI.
    var refreshAutomatically: Bool = false
    var refreshIntervalSeconds: Int = 60
    var preferredTerminal: PreferredTerminal = .automatic
    /// Off by default — MenuBarExtra has caused launch freezes on some machines.
    var showMenuBarExtra: Bool = false
    var projectRoots: [String] = ["~/Developer", "~/Projects"]
    var additionalBinaryPaths: [String] = []
    var additionalConfigDirectories: [String] = []
    var showCommandLogs: Bool = false

    static let storageURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("HarnessManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("settings.json")
    }()
}

struct PackageManagerInfo: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let isInstalled: Bool
    let path: String?
    let version: String?
}
