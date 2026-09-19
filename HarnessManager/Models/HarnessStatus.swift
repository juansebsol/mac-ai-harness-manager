import Foundation

enum HarnessStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case running
    case installed
    case updateAvailable
    case misconfigured
    case unavailable
    case unknown

    var displayName: String {
        switch self {
        case .running: return "Running"
        case .installed: return "Installed"
        case .updateAvailable: return "Update Available"
        case .misconfigured: return "Misconfigured"
        case .unavailable: return "Not Installed"
        case .unknown: return "Unknown"
        }
    }

    var sortOrder: Int {
        switch self {
        case .running: return 0
        case .updateAvailable: return 1
        case .misconfigured: return 2
        case .installed: return 3
        case .unknown: return 4
        case .unavailable: return 5
        }
    }
}

enum UpdateStatus: String, Codable, Hashable, Sendable {
    case current
    case updateAvailable
    case unknown
    case notApplicable

    var displayName: String {
        switch self {
        case .current: return "Current"
        case .updateAvailable: return "Update Available"
        case .unknown: return "—"
        case .notApplicable: return "—"
        }
    }
}
