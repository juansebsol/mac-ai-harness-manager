import Foundation
import OSLog

actor UpdateCheckService {
    static let shared = UpdateCheckService()

    private let logger = Logger(subsystem: "com.harnessmanager.app", category: "Updates")

    func checkUpdates(
        snapshots: [HarnessSnapshot],
        pathEnvironment: String,
        force: Bool = false
    ) async -> [HarnessSnapshot] {
        var updated: [HarnessSnapshot] = []
        for snapshot in snapshots {
            var copy = snapshot
            guard snapshot.isInstalled,
                  let definition = HarnessRegistry.definition(for: snapshot.definitionId)
            else {
                copy.updateStatus = .notApplicable
                updated.append(copy)
                continue
            }

            let latest = await latestVersion(
                definition: definition,
                installSource: snapshot.installSource,
                pathEnvironment: pathEnvironment,
                force: force
            )
            copy.latestVersion = latest

            if let installed = normalizeVersion(snapshot.installedVersion),
               let remote = normalizeVersion(latest),
               !remote.isEmpty,
               installed != remote,
               isVersion(remote, newerThan: installed) {
                copy.updateStatus = .updateAvailable
                if copy.status == .installed || copy.status == .running {
                    // Preserve running; mark update in updateStatus field.
                }
            } else if latest != nil && normalizeVersion(snapshot.installedVersion) != nil {
                copy.updateStatus = .current
            } else {
                copy.updateStatus = .unknown
            }
            updated.append(copy)
        }
        return updated
    }

    /// Build a user-confirmable update command. Never executes.
    func proposedUpdateCommand(
        definition: HarnessDefinition,
        installSource: DetectedInstallSource,
        pathEnvironment: String
    ) -> (executable: URL, arguments: [String], display: String)? {
        switch installSource {
        case .homebrew:
            guard let formula = definition.installationMethods.compactMap({ method -> String? in
                if case .homebrew(let f) = method { return f }
                return nil
            }).first else { return nil }
            let brewCandidates = [
                CommandRunner.resolveExecutable(named: "brew", pathEnvironment: pathEnvironment),
                URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
                URL(fileURLWithPath: "/usr/local/bin/brew")
            ].compactMap { $0 }
            guard let brew = brewCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) })
            else { return nil }
            return (brew, ["upgrade", formula], "brew upgrade \(formula)")

        case .npm:
            guard let package = definition.installationMethods.compactMap({ method -> String? in
                if case .npm(let p) = method { return p }
                return nil
            }).first,
                  let npm = CommandRunner.resolveExecutable(named: "npm", pathEnvironment: pathEnvironment)
            else { return nil }
            return (npm, ["install", "-g", "\(package)@latest"], "npm install -g \(package)@latest")

        case .pnpm:
            guard let package = definition.installationMethods.compactMap({ method -> String? in
                if case .pnpm(let p) = method { return p }
                return nil
            }).first,
                  let pnpm = CommandRunner.resolveExecutable(named: "pnpm", pathEnvironment: pathEnvironment)
            else { return nil }
            return (pnpm, ["add", "-g", "\(package)@latest"], "pnpm add -g \(package)@latest")

        case .bun:
            guard let package = definition.installationMethods.compactMap({ method -> String? in
                if case .bun(let p) = method { return p }
                return nil
            }).first,
                  let bun = CommandRunner.resolveExecutable(named: "bun", pathEnvironment: pathEnvironment)
            else { return nil }
            return (bun, ["add", "-g", "\(package)@latest"], "bun add -g \(package)@latest")

        case .standalone:
            guard definition.id == "claude-code",
                  let binary = CommandRunner.resolveExecutable(named: "claude", pathEnvironment: pathEnvironment) else { return nil }
            return (binary, ["update"], "claude update")
        case .macApplication, .unknown:
            return nil
        }
    }

    /// Build a user-confirmable install command. Never executes.
    func proposedInstallCommand(
        definition: HarnessDefinition,
        packageManagers: [PackageManagerInfo],
        pathEnvironment: String
    ) -> (executable: URL, arguments: [String], display: String)? {
        let installed = Set(packageManagers.filter(\.isInstalled).map(\.id))

        for method in definition.installationMethods {
            switch method {
            case .homebrew(let formula):
                guard installed.contains("homebrew") else { continue }
                let brewCandidates = [
                    CommandRunner.resolveExecutable(named: "brew", pathEnvironment: pathEnvironment),
                    URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
                    URL(fileURLWithPath: "/usr/local/bin/brew")
                ].compactMap { $0 }
                guard let brew = brewCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) })
                else { continue }
                return (brew, ["install", formula], "brew install \(formula)")

            case .npm(let package):
                guard installed.contains("npm"),
                      let npm = CommandRunner.resolveExecutable(named: "npm", pathEnvironment: pathEnvironment)
                else { continue }
                return (npm, ["install", "-g", package], "npm install -g \(package)")

            case .pnpm(let package):
                guard installed.contains("pnpm"),
                      let pnpm = CommandRunner.resolveExecutable(named: "pnpm", pathEnvironment: pathEnvironment)
                else { continue }
                return (pnpm, ["add", "-g", package], "pnpm add -g \(package)")

            case .bun(let package):
                guard installed.contains("bun"),
                      let bun = CommandRunner.resolveExecutable(named: "bun", pathEnvironment: pathEnvironment)
                else { continue }
                return (bun, ["add", "-g", package], "bun add -g \(package)")

            case .macApplication, .standalone:
                continue
            }
        }
        return nil
    }

    private func latestVersion(
        definition: HarnessDefinition,
        installSource: DetectedInstallSource,
        pathEnvironment: String,
        force: Bool
    ) async -> String? {
        let cacheKey = "\(definition.id):\(installSource.rawValue)"
        if !force, let cached = await DiscoveryCache.shared.cachedLatestVersion(key: cacheKey) {
            return cached
        }

        let version: String?
        switch installSource {
        case .homebrew:
            version = await brewLatest(definition: definition, path: pathEnvironment)
        case .npm, .pnpm, .bun:
            version = await npmLatest(definition: definition, path: pathEnvironment)
        case .standalone:
            version = definition.id == "claude-code" ? await npmLatest(definition: definition, path: pathEnvironment) : nil
        case .macApplication, .unknown:
            version = nil
        }

        await DiscoveryCache.shared.storeLatestVersion(key: cacheKey, version: version)
        return version
    }

    private func brewLatest(definition: HarnessDefinition, path: String) async -> String? {
        guard let formula = definition.installationMethods.compactMap({ method -> String? in
            if case .homebrew(let f) = method { return f }
            return nil
        }).first,
              let brew = CommandRunner.resolveExecutable(named: "brew", pathEnvironment: path)
                ?? [URL(fileURLWithPath: "/opt/homebrew/bin/brew"), URL(fileURLWithPath: "/usr/local/bin/brew")]
                .first(where: { FileManager.default.isExecutableFile(atPath: $0.path) })
        else { return nil }

        do {
            let result = try await CommandRunner.shared.run(
                executable: brew, arguments: ["info", "--json=v2", formula],
                environment: ["PATH": path], timeout: 25
            )
            guard result.succeeded,
                  let data = result.stdout.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            if let formula = (json["formulae"] as? [[String: Any]])?.first,
               let versions = formula["versions"] as? [String: Any] { return versions["stable"] as? String }
            return (json["casks"] as? [[String: Any]])?.first?["version"] as? String
        } catch { return nil }
    }

    private func npmLatest(definition: HarnessDefinition, path: String) async -> String? {
        guard let package = definition.installationMethods.compactMap({ method -> String? in
            switch method {
            case .npm(let p), .pnpm(let p), .bun(let p): return p
            default: return nil
            }
        }).first else { return nil }
        do {
            let escaped = package.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/")))!
            let url = URL(string: "https://registry.npmjs.org/\(escaped)/latest")!
            let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 20))
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            return object["version"] as? String
        } catch { return nil }
    }

    private func normalizeVersion(_ raw: String?) -> String? {
        guard var text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        // Extract first semver-like token
        let pattern = #"(\d+\.\d+(?:\.\d+)?)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        if text.lowercased().hasPrefix("v") {
            text.removeFirst()
        }
        return text
    }

    private func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        let l = lhs.split(separator: ".").compactMap { Int($0) }
        let r = rhs.split(separator: ".").compactMap { Int($0) }
        let count = max(l.count, r.count)
        for i in 0..<count {
            let a = i < l.count ? l[i] : 0
            let b = i < r.count ? r[i] : 0
            if a != b { return a > b }
        }
        return false
    }
}

/// Interactive setup stays in Terminal so macOS passwords never pass through the app.
enum HomebrewBootstrap {
    static func formula(for definition: HarnessDefinition) -> String? {
        definition.installationMethods.compactMap {
            if case .homebrew(let formula) = $0 { return formula }
            return nil
        }.first
    }

    static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func script(formula: String, directory: URL) -> String {
        let status = quote(directory.appendingPathComponent("status").path)
        let installer = quote(directory.appendingPathComponent("homebrew-install.sh").path)
        return """
        #!/bin/bash
        set -e
        trap 'result=$?; echo "$result" > \(status); if [ "$result" -ne 0 ]; then echo "Installation stopped. Return to Harness Manager to retry."; fi' EXIT
        export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
        if ! command -v brew >/dev/null 2>&1; then
          echo "Setting up Homebrew. Its installer may request your Mac password and Command Line Tools."
          /usr/bin/curl --fail --show-error --location https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o \(installer)
          /bin/bash \(installer)
        fi
        command -v brew >/dev/null 2>&1 || { echo "Homebrew is unavailable."; exit 1; }
        brew install \(quote(formula))
        echo "Installation complete. You can close this Terminal window."
        """
    }
}
