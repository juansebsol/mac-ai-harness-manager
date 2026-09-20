import Foundation
import OSLog

actor ProjectScannerService {
    static let shared = ProjectScannerService()

    private let logger = Logger(subsystem: "com.harnessmanager.app", category: "Projects")

    private let markers = [
        ".git",
        "package.json",
        "Cargo.toml",
        "Package.swift",
        "pyproject.toml",
        "go.mod",
        "Gemfile",
        "composer.json",
        "mix.exs"
    ]

    /// Shallow scan of configured project roots only — never the entire home directory.
    func scan(roots: [String], maxDepth: Int = 3) async -> [CodingProject] {
        let fm = FileManager.default
        var projects: [CodingProject] = []
        var seen = Set<String>()

        for root in roots {
            let expanded = (root as NSString).expandingTildeInPath
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: expanded, isDirectory: &isDir), isDir.boolValue else { continue }

            await scanDirectory(
                URL(fileURLWithPath: expanded),
                depth: 0,
                maxDepth: maxDepth,
                projects: &projects,
                seen: &seen
            )
        }

        return projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func scanDirectory(
        _ url: URL,
        depth: Int,
        maxDepth: Int,
        projects: inout [CodingProject],
        seen: inout Set<String>
    ) async {
        let fm = FileManager.default
        let path = url.path
        guard !seen.contains(path) else { return }

        let foundMarkers = markers.filter { marker in
            fm.fileExists(atPath: url.appendingPathComponent(marker).path)
        }

        if !foundMarkers.isEmpty {
            seen.insert(path)
            let branch = await gitBranch(at: url)
            projects.append(
                CodingProject(
                    id: path,
                    name: url.lastPathComponent,
                    path: path,
                    gitBranch: branch,
                    activeHarnessId: nil,
                    activeHarnessName: nil,
                    lastOpened: nil,
                    markers: foundMarkers
                )
            )
            // Do not descend into project interiors.
            return
        }

        guard depth < maxDepth else { return }

        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for child in contents {
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            let name = child.lastPathComponent
            if name == "node_modules" || name == "DerivedData" || name == ".build" { continue }
            await scanDirectory(child, depth: depth + 1, maxDepth: maxDepth, projects: &projects, seen: &seen)
        }
    }

    private func gitBranch(at url: URL) async -> String? {
        let git = URL(fileURLWithPath: "/usr/bin/git")
        guard FileManager.default.isExecutableFile(atPath: git.path) else { return nil }
        do {
            let result = try await CommandRunner.shared.run(
                executable: git,
                arguments: ["rev-parse", "--abbrev-ref", "HEAD"],
                workingDirectory: url,
                timeout: 5
            )
            let branch = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return branch.isEmpty ? nil : branch
        } catch {
            return nil
        }
    }
}
