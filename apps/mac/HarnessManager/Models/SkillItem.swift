import Foundation

enum SkillScope: String, Codable, Hashable, Sendable {
    case global
    case project

    var displayName: String {
        switch self {
        case .global: return "Global"
        case .project: return "Project"
        }
    }
}

struct SkillItem: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let source: String
    let harnessId: String?
    let harnessName: String?
    let scope: SkillScope
    let location: String
}
