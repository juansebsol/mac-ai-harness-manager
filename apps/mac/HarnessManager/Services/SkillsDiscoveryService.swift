import Foundation
import OSLog

actor SkillsDiscoveryService {
    static let shared = SkillsDiscoveryService()

    private let logger = Logger(subsystem: "com.harnessmanager.app", category: "Skills")

    func discover(
        definitions: [HarnessDefinition] = HarnessRegistry.all,
        projectRoots: [String] = []
    ) async -> [SkillItem] {
        var items: [SkillItem] = []

        for definition in definitions {
            for spec in definition.configPaths where spec.label.lowercased().contains("skill") || spec.path.lowercased().contains("skill") {
                let url = spec.expandedURL()
                items.append(contentsOf: scanSkillsDirectory(url, harness: definition, scope: .global, source: spec.label))
            }

            // Well-known skill locations
            for dir in wellKnownSkillDirs(for: definition) {
                items.append(contentsOf: scanSkillsDirectory(dir, harness: definition, scope: .global, source: "Skills"))
            }
        }

        // Project-scoped agent instruction files (shallow)
        let fm = FileManager.default
        for root in projectRoots {
            let expanded = (root as NSString).expandingTildeInPath
            guard let contents = try? fm.contentsOfDirectory(atPath: expanded) else { continue }
            for name in contents {
                let projectPath = (expanded as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: projectPath, isDirectory: &isDir), isDir.boolValue else { continue }
                for relative in ["AGENTS.md", "CLAUDE.md", ".cursor/rules", ".claude/skills"] {
                    let candidate = (projectPath as NSString).appendingPathComponent(relative)
                    if fm.fileExists(atPath: candidate) {
                        items.append(
                            SkillItem(
                                id: candidate,
                                name: (relative as NSString).lastPathComponent,
                                source: "Project file",
                                harnessId: nil,
                                harnessName: nil,
                                scope: .project,
                                location: candidate
                            )
                        )
                    }
                }
            }
        }

        // Deduplicate by location
        var seen = Set<String>()
        return items.filter { seen.insert($0.location).inserted }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func wellKnownSkillDirs(for definition: HarnessDefinition) -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch definition.id {
        case "claude-code":
            return [
                home.appendingPathComponent(".claude/skills"),
                home.appendingPathComponent(".claude/commands")
            ]
        case "cursor":
            return [
                home.appendingPathComponent(".cursor/skills"),
                home.appendingPathComponent(".cursor/rules")
            ]
        case "codex":
            return [home.appendingPathComponent(".codex/skills")]
        default:
            return []
        }
    }

    private func scanSkillsDirectory(
        _ url: URL,
        harness: HarnessDefinition,
        scope: SkillScope,
        source: String
    ) -> [SkillItem] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return [] }

        if !isDir.boolValue {
            return [
                SkillItem(
                    id: url.path,
                    name: url.lastPathComponent,
                    source: source,
                    harnessId: harness.id,
                    harnessName: harness.name,
                    scope: scope,
                    location: url.path
                )
            ]
        }

        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents.map { child in
            SkillItem(
                id: child.path,
                name: child.deletingPathExtension().lastPathComponent,
                source: source,
                harnessId: harness.id,
                harnessName: harness.name,
                scope: scope,
                location: child.path
            )
        }
    }
}
