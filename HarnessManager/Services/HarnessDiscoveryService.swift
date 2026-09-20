import Foundation
import OSLog

/// Discovers harnesses without touching AppKit/NSWorkspace (those can deadlock the UI).
actor HarnessDiscoveryService {
    static let shared = HarnessDiscoveryService()

    private let logger = Logger(subsystem: "com.harnessmanager.app", category: "Discovery")
    private let maxConcurrent = 4

    struct ScanContext: Sendable {
        let pathEnvironment: String
        let packageScan: DiscoveryCache.PackageManagerScan
        let additionalConfigDirectories: [String]
        let runVersionCommands: Bool
    }

    /// Fast pass: PATH + filesystem only. No subprocesses, no AppKit.
    func discoverFast(
        definitions: [HarnessDefinition] = HarnessRegistry.all,
        settings: AppSettings
    ) async -> [HarnessSnapshot] {
        let path = await PathEnvironmentService.shared.fastPATH(additionalPaths: settings.additionalBinaryPaths)
        let packageScan = await DiscoveryCache.shared.cachedPackageScan()
            ?? DiscoveryCache.PackageManagerScan(
                brewFormulas: [],
                npmPackages: [],
                pnpmPackages: [],
                bunPackages: [],
                scannedAt: .distantPast
            )

        let context = ScanContext(
            pathEnvironment: path,
            packageScan: packageScan,
            additionalConfigDirectories: settings.additionalConfigDirectories,
            runVersionCommands: false
        )

        return definitions.map { definition in
            discoverOneSync(definition: definition, context: context)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Slower pass: versions + package manager inventory. Still no AppKit.
    func discoverAll(
        definitions: [HarnessDefinition] = HarnessRegistry.all,
        settings: AppSettings,
        onProgress: @Sendable @escaping (HarnessSnapshot) -> Void
    ) async -> [HarnessSnapshot] {
        let path = await PathEnvironmentService.shared.currentPATH(additionalPaths: settings.additionalBinaryPaths)

        // The fast pass already painted the UI. Enrichment needs a fresh inventory
        // so the first scan and post-install refresh identify the owning manager.
        let packageScan = await PackageManagerService.shared.scanInstalledPackages(pathEnvironment: path, force: true)

        let context = ScanContext(
            pathEnvironment: path,
            packageScan: packageScan,
            additionalConfigDirectories: settings.additionalConfigDirectories,
            runVersionCommands: true
        )

        var results: [HarnessSnapshot] = []
        results.reserveCapacity(definitions.count)

        await withTaskGroup(of: HarnessSnapshot.self) { group in
            var iterator = definitions.makeIterator()
            var inFlight = 0

            func enqueueNext() {
                while inFlight < maxConcurrent, let definition = iterator.next() {
                    inFlight += 1
                    group.addTask {
                        await self.discoverOne(definition: definition, context: context)
                    }
                }
            }

            enqueueNext()

            for await snapshot in group {
                inFlight -= 1
                results.append(snapshot)
                onProgress(snapshot)
                enqueueNext()
            }
        }

        await DiscoveryCache.shared.storeSnapshots(results)
        logger.info("Discovered \(results.count) harness definitions")
        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func discoverOne(definition: HarnessDefinition, context: ScanContext) async -> HarnessSnapshot {
        var snapshot = discoverOneSync(definition: definition, context: context)
        if context.runVersionCommands, let binaryPath = snapshot.binaryPath {
            let binaryVersion = await readVersion(
                executable: URL(fileURLWithPath: binaryPath),
                arguments: definition.versionArguments,
                path: context.pathEnvironment
            )
            if let binaryVersion { snapshot.installedVersion = binaryVersion }
        }
        return snapshot
    }

    /// Pure filesystem / PATH resolution — safe to call anywhere.
    nonisolated func discoverOneSync(definition: HarnessDefinition, context: ScanContext) -> HarnessSnapshot {
        let binary = findBinary(definition: definition, pathEnvironment: context.pathEnvironment)
        let appPath = findApplication(definition: definition)
        let isInstalled = binary != nil || appPath != nil

        let resolvedSource = detectInstallSourceLocally(
            definition: definition,
            binaryPath: binary?.path,
            scan: context.packageScan,
            hasApp: appPath != nil
        )

        let configs = discoverConfigs(definition: definition, additional: context.additionalConfigDirectories)
        let status: HarnessStatus = isInstalled ? .installed : .unavailable

        return HarnessSnapshot(
            definitionId: definition.id,
            name: definition.name,
            status: status,
            installedVersion: appPath.flatMap { path in
                guard let info = NSDictionary(contentsOfFile: path + "/Contents/Info.plist") else { return nil }
                return info["CFBundleShortVersionString"] as? String ?? info["CFBundleVersion"] as? String
            },
            latestVersion: nil,
            updateStatus: .unknown,
            installSource: resolvedSource,
            binaryPath: binary?.path,
            applicationPath: appPath,
            providerIds: definition.providerIds,
            activeProject: nil,
            configItems: configs,
            processCount: 0,
            isInstalled: isInstalled,
            lastScannedAt: Date(),
            definitionIncomplete: !definition.isComplete
        )
    }

    nonisolated func findBinary(definition: HarnessDefinition, pathEnvironment: String) -> URL? {
        for name in definition.binaryNames {
            if let url = CommandRunner.resolveExecutable(named: name, pathEnvironment: pathEnvironment) {
                return url
            }
        }
        return nil
    }

    /// Filesystem-only app detection — never call NSWorkspace from a background actor.
    nonisolated func findApplication(definition: HarnessDefinition) -> String? {
        let fm = FileManager.default
        let searchRoots = [
            "/Applications",
            NSHomeDirectory() + "/Applications"
        ]

        let candidateNames: [String] = {
            switch definition.id {
            case "cursor": return ["Cursor.app"]
            case "warp": return ["Warp.app"]
            case "kiro": return ["Kiro.app"]
            default:
                return [definition.name + ".app"]
            }
        }()

        for root in searchRoots {
            for name in candidateNames {
                let full = (root as NSString).appendingPathComponent(name)
                if fm.fileExists(atPath: full) {
                    return full
                }
            }

            // Fallback: match bundle identifier from Info.plist without NSWorkspace.
            guard !definition.applicationBundleIdentifiers.isEmpty,
                  let contents = try? fm.contentsOfDirectory(atPath: root)
            else { continue }

            for item in contents where item.hasSuffix(".app") {
                let full = (root as NSString).appendingPathComponent(item)
                let plistPath = (full as NSString).appendingPathComponent("Contents/Info.plist")
                guard let plist = NSDictionary(contentsOfFile: plistPath),
                      let bundleId = plist["CFBundleIdentifier"] as? String,
                      definition.applicationBundleIdentifiers.contains(bundleId)
                else { continue }
                return full
            }
        }
        return nil
    }

    nonisolated private func detectInstallSourceLocally(
        definition: HarnessDefinition,
        binaryPath: String?,
        scan: DiscoveryCache.PackageManagerScan,
        hasApp: Bool
    ) -> DetectedInstallSource {
        for method in definition.installationMethods {
            switch method {
            case .homebrew(let formula):
                if scan.brewFormulas.contains(where: { $0 == formula || $0.hasSuffix("/\(formula)") }) {
                    return .homebrew
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
            case .macApplication, .standalone:
                continue
            }
        }

        if let binaryPath {
            if binaryPath.contains("/node_modules/") || binaryPath.contains(".npm") { return .npm }
            if binaryPath.contains("/Cellar/") || binaryPath.contains("homebrew") { return .homebrew }
            if binaryPath.contains("/.bun/") { return .bun }
            if binaryPath.contains("/pnpm/") { return .pnpm }
            if hasApp { return .macApplication }
            return .standalone
        }

        if hasApp { return .macApplication }
        return .unknown
    }

    private func readVersion(executable: URL, arguments: [String], path: String) async -> String? {
        do {
            let result = try await CommandRunner.shared.run(
                executable: executable,
                arguments: arguments,
                environment: ["PATH": path],
                timeout: 4
            )
            guard result.succeeded else { return nil }
            let text = (result.stdout.isEmpty ? result.stderr : result.stdout)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return text.components(separatedBy: .newlines).first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    nonisolated private func discoverConfigs(definition: HarnessDefinition, additional: [String]) -> [DiscoveredConfig] {
        var items: [DiscoveredConfig] = []
        let fm = FileManager.default

        for spec in definition.configPaths {
            let url = spec.expandedURL()
            let exists: Bool
            switch spec.kind {
            case .directory:
                var isDir: ObjCBool = false
                exists = fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
            case .file, .glob:
                exists = fm.fileExists(atPath: url.path)
            }
            items.append(
                DiscoveredConfig(
                    label: spec.label,
                    path: url.path,
                    exists: exists,
                    kind: spec.kind
                )
            )
        }

        for extra in additional {
            let expanded = (extra as NSString).expandingTildeInPath
            var isDir: ObjCBool = false
            let exists = fm.fileExists(atPath: expanded, isDirectory: &isDir)
            items.append(
                DiscoveredConfig(
                    label: "Additional",
                    path: expanded,
                    exists: exists,
                    kind: isDir.boolValue ? .directory : .file
                )
            )
        }

        return items
    }
}
