import Foundation
import OSLog

actor PackageManagerService {
    static let shared = PackageManagerService()

    private let logger = Logger(subsystem: "com.harnessmanager.app", category: "PackageManagers")

    func detectPackageManagers(pathEnvironment: String) async -> [PackageManagerInfo] {
        async let brew = detectBrew(path: pathEnvironment)
        async let npm = detectTool(name: "npm", displayName: "npm", path: pathEnvironment, versionArgs: ["--version"])
        async let pnpm = detectTool(name: "pnpm", displayName: "pnpm", path: pathEnvironment, versionArgs: ["--version"])
        async let bun = detectTool(name: "bun", displayName: "bun", path: pathEnvironment, versionArgs: ["--version"])
        return await [brew, npm, pnpm, bun]
    }

    func scanInstalledPackages(pathEnvironment: String, force: Bool = false) async -> DiscoveryCache.PackageManagerScan {
        if !force, let cached = await DiscoveryCache.shared.cachedPackageScan() {
            return cached
        }

        async let brewFormulas = listBrewFormulas(path: pathEnvironment)
        async let npmPackages = listNpmGlobals(path: pathEnvironment)
        async let pnpmPackages = listPnpmGlobals(path: pathEnvironment)
        async let bunPackages = listBunGlobals(path: pathEnvironment)

        let scan = await DiscoveryCache.PackageManagerScan(
            brewFormulas: brewFormulas,
            npmPackages: npmPackages,
            pnpmPackages: pnpmPackages,
            bunPackages: bunPackages,
            scannedAt: Date()
        )
        await DiscoveryCache.shared.storePackageScan(scan)
        return scan
    }

    func detectInstallSource(
        definition: HarnessDefinition,
        binaryPath: String?,
        scan: DiscoveryCache.PackageManagerScan
    ) -> DetectedInstallSource {
        for method in definition.installationMethods {
            switch method {
            case .homebrew(let formula):
                if scan.brewFormulas.contains(where: { $0 == formula || $0.hasSuffix("/\(formula)") }) {
                    return .homebrew
                }
                if let binaryPath, binaryPath.contains("/Cellar/") || binaryPath.contains("/opt/homebrew/") {
                    // Prefer package list match; path alone is weak signal for npm-linked brew shims.
                    break
                }
            case .npm(let package):
                if scan.npmPackages.contains(where: { $0 == package || $0.hasSuffix(package) }) {
                    return .npm
                }
            case .pnpm(let package):
                if scan.pnpmPackages.contains(where: { $0 == package || $0.hasSuffix(package) }) {
                    return .pnpm
                }
            case .bun(let package):
                if scan.bunPackages.contains(where: { $0 == package || $0.hasSuffix(package) }) {
                    return .bun
                }
            case .macApplication:
                continue
            case .standalone:
                continue
            }
        }

        if binaryPath != nil {
            if let binaryPath {
                if binaryPath.contains("/node_modules/") || binaryPath.contains("/npm/") {
                    return .npm
                }
                if binaryPath.contains("/Cellar/") || binaryPath.contains("homebrew") {
                    return .homebrew
                }
                if binaryPath.contains("/.bun/") {
                    return .bun
                }
                if binaryPath.contains("/pnpm/") {
                    return .pnpm
                }
            }
            return .standalone
        }

        if !definition.applicationBundleIdentifiers.isEmpty {
            return .macApplication
        }

        return .unknown
    }

    // MARK: - Private

    private func detectBrew(path: String) async -> PackageManagerInfo {
        let brewURL = CommandRunner.resolveExecutable(named: "brew", pathEnvironment: path)
            ?? [URL(fileURLWithPath: "/opt/homebrew/bin/brew"), URL(fileURLWithPath: "/usr/local/bin/brew")]
            .first(where: { FileManager.default.isExecutableFile(atPath: $0.path) })

        guard let brewURL else {
            return PackageManagerInfo(id: "homebrew", name: "Homebrew", isInstalled: false, path: nil, version: nil)
        }

        let version = await readVersion(executable: brewURL, args: ["--version"])
        return PackageManagerInfo(
            id: "homebrew",
            name: "Homebrew",
            isInstalled: true,
            path: brewURL.path,
            version: version?.components(separatedBy: .newlines).first
        )
    }

    private func detectTool(name: String, displayName: String, path: String, versionArgs: [String]) async -> PackageManagerInfo {
        guard let url = CommandRunner.resolveExecutable(named: name, pathEnvironment: path) else {
            return PackageManagerInfo(id: name, name: displayName, isInstalled: false, path: nil, version: nil)
        }
        let version = await readVersion(executable: url, args: versionArgs)
        return PackageManagerInfo(id: name, name: displayName, isInstalled: true, path: url.path, version: version)
    }

    private func readVersion(executable: URL, args: [String]) async -> String? {
        do {
            let result = try await CommandRunner.shared.run(executable: executable, arguments: args, timeout: 8)
            let text = (result.stdout.isEmpty ? result.stderr : result.stdout)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }

    private func listBrewFormulas(path: String) async -> [String] {
        guard let brew = CommandRunner.resolveExecutable(named: "brew", pathEnvironment: path)
            ?? [URL(fileURLWithPath: "/opt/homebrew/bin/brew"), URL(fileURLWithPath: "/usr/local/bin/brew")]
            .first(where: { FileManager.default.isExecutableFile(atPath: $0.path) })
        else { return [] }

        do {
            let result = try await CommandRunner.shared.run(executable: brew, arguments: ["list", "-1"], environment: ["PATH": path], timeout: 12)
            return result.stdout
                .split(whereSeparator: \.isNewline)
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        } catch {
            logger.error("brew list failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private func listNpmGlobals(path: String) async -> [String] {
        guard let npm = CommandRunner.resolveExecutable(named: "npm", pathEnvironment: path) else { return [] }
        do {
            let result = try await CommandRunner.shared.run(
                executable: npm,
                arguments: ["list", "-g", "--depth=0", "--json"],
                environment: ["PATH": path],
                timeout: 25
            )
            return parseNpmStylePackageNames(from: result.stdout)
        } catch {
            return []
        }
    }

    private func listPnpmGlobals(path: String) async -> [String] {
        guard let pnpm = CommandRunner.resolveExecutable(named: "pnpm", pathEnvironment: path) else { return [] }
        do {
            let result = try await CommandRunner.shared.run(
                executable: pnpm,
                arguments: ["list", "-g", "--depth", "0", "--json"],
                environment: ["PATH": path],
                timeout: 25
            )
            return parsePnpmPackageNames(from: result.stdout)
        } catch {
            return []
        }
    }

    private func listBunGlobals(path: String) async -> [String] {
        guard let bun = CommandRunner.resolveExecutable(named: "bun", pathEnvironment: path) else { return [] }
        // `bun pm ls -g` varies by version; try JSON first, fall back to plain text.
        do {
            let result = try await CommandRunner.shared.run(
                executable: bun,
                arguments: ["pm", "ls", "-g"],
                environment: ["PATH": path],
                timeout: 20
            )
            return result.stdout
                .split(whereSeparator: \.isNewline)
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .compactMap { line -> String? in
                    let parts = line.split(separator: " ")
                    guard let last = parts.last else { return nil }
                    let token = String(last)
                    guard let versionSeparator = token.lastIndex(of: "@"), versionSeparator != token.startIndex else { return nil }
                    return String(token[..<versionSeparator])
                }
        } catch {
            return []
        }
    }

    private func parseNpmStylePackageNames(from json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let deps = obj["dependencies"] as? [String: Any]
        else { return [] }
        return Array(deps.keys)
    }

    private func parsePnpmPackageNames(from json: String) -> [String] {
        guard let data = json.data(using: .utf8) else { return [] }
        if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return arr.flatMap { item in
                Array((item["dependencies"] as? [String: Any] ?? [:]).keys)
            }
        }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let deps = obj["dependencies"] as? [String: Any] {
            return Array(deps.keys)
        }
        return []
    }
}
