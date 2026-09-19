import Foundation

enum InstallationMethod: Codable, Hashable, Sendable {
    case homebrew(formula: String)
    case npm(package: String)
    case pnpm(package: String)
    case bun(package: String)
    case standalone
    case macApplication

    var displayName: String {
        switch self {
        case .homebrew: return "Homebrew"
        case .npm: return "npm"
        case .pnpm: return "pnpm"
        case .bun: return "bun"
        case .standalone: return "Standalone"
        case .macApplication: return "macOS App"
        }
    }

    var shortName: String {
        switch self {
        case .homebrew: return "brew"
        case .npm: return "npm"
        case .pnpm: return "pnpm"
        case .bun: return "bun"
        case .standalone: return "standalone"
        case .macApplication: return "app"
        }
    }

    var packageIdentifier: String? {
        switch self {
        case .homebrew(let formula): return formula
        case .npm(let package): return package
        case .pnpm(let package): return package
        case .bun(let package): return package
        case .standalone, .macApplication: return nil
        }
    }
}

enum DetectedInstallSource: String, Codable, Hashable, Sendable {
    case homebrew
    case npm
    case pnpm
    case bun
    case macApplication
    case standalone
    case unknown

    var displayName: String {
        switch self {
        case .homebrew: return "Homebrew"
        case .npm: return "npm"
        case .pnpm: return "pnpm"
        case .bun: return "bun"
        case .macApplication: return "macOS App"
        case .standalone: return "Standalone"
        case .unknown: return "Unknown"
        }
    }
}
