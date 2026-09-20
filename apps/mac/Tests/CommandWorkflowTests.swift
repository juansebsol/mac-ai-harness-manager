import Foundation

@main struct CommandWorkflowTests {
    static func main() async throws {
        let fm = FileManager.default
        let directory = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: directory) }
        for name in ["brew", "npm", "pnpm", "bun", "claude"] {
            let script = "#!/bin/sh\nprintf '%s\\n' \"$@\"\nprintf 'diagnostic\\n' >&2\n"
            let url = directory.appendingPathComponent(name)
            try script.write(to: url, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
        let path = directory.path + ":/usr/bin:/bin"
        let service = UpdateCheckService.shared
        let definition = ClaudeCodeDefinition.definition
        for (manager, source) in [("homebrew", DetectedInstallSource.homebrew), ("npm", .npm), ("pnpm", .pnpm), ("bun", .bun)] {
            let executableName = manager == "homebrew" ? "brew" : manager
            let info = PackageManagerInfo(id: manager, name: manager, isInstalled: true, path: directory.appendingPathComponent(executableName).path, version: "1.0")
            guard let install = await service.proposedInstallCommand(definition: definition, packageManagers: [info], pathEnvironment: path) else { fatalError("Missing install: \(manager)") }
            precondition(install.executable.lastPathComponent == executableName)
            let result = try await CommandRunner.shared.run(executable: install.executable, arguments: install.arguments, environment: ["PATH": path])
            precondition(result.succeeded && result.stdout.contains(install.arguments.last!))
            precondition(result.stderr.contains("diagnostic"))
            guard let update = await service.proposedUpdateCommand(definition: definition, installSource: source, pathEnvironment: path) else { fatalError("Missing update: \(manager)") }
            precondition(update.executable.lastPathComponent == executableName)
            precondition(update.arguments.contains(manager == "homebrew" ? "upgrade" : "-g"))
        }
        let native = await service.proposedUpdateCommand(definition: definition, installSource: .standalone, pathEnvironment: path)
        precondition(native?.arguments == ["update"] && native?.executable.lastPathComponent == "claude")
        let cursorInstall = await service.proposedInstallCommand(definition: CursorDefinition.definition, packageManagers: [PackageManagerInfo(id: "homebrew", name: "Homebrew", isInstalled: true, path: nil, version: nil)], pathEnvironment: path)
        precondition(cursorInstall?.arguments == ["install", "cursor"])
        let antigravity = AntigravityIDEDefinition.definition
        precondition(HarnessRegistry.complete.contains { $0.id == antigravity.id })
        let ideInstall = await service.proposedInstallCommand(definition: antigravity, packageManagers: [PackageManagerInfo(id: "homebrew", name: "Homebrew", isInstalled: true, path: nil, version: nil)], pathEnvironment: path)
        precondition(ideInstall?.arguments == ["install", "antigravity-ide"])
        let ideUpdate = await service.proposedUpdateCommand(definition: antigravity, installSource: .homebrew, pathEnvironment: path)
        precondition(ideUpdate?.arguments == ["upgrade", "antigravity-ide"])
        let hub = AntigravityDefinition.definition
        precondition(hub.id != antigravity.id)
        precondition(Set(HarnessRegistry.all.map(\.id)).count == HarnessRegistry.all.count)
        precondition(Set(hub.applicationBundleIdentifiers).isDisjoint(with: antigravity.applicationBundleIdentifiers))
        let hubInstall = await service.proposedInstallCommand(definition: hub, packageManagers: [PackageManagerInfo(id: "homebrew", name: "Homebrew", isInstalled: true, path: nil, version: nil)], pathEnvironment: path)
        precondition(hubInstall?.arguments == ["install", "antigravity"])
        let hubUpdate = await service.proposedUpdateCommand(definition: hub, installSource: .homebrew, pathEnvironment: path)
        precondition(hubUpdate?.arguments == ["upgrade", "antigravity"])
        let ideManualUpdate = await service.proposedUpdateCommand(definition: antigravity, installSource: .macApplication, pathEnvironment: path)
        precondition(ideManualUpdate == nil)
        let metaIDs = Set(["warp", "paseo", "t3-code", "conductor", "superset", "cmux", "orca", "herdr", "emdash", "antigravity", "openchamber", "vibe-kanban"])
        precondition(Set(HarnessRegistry.all.filter(\.isMetaHarness).map(\.id)) == metaIDs)
        for tool in HarnessRegistry.all.filter({ $0.isMetaHarness && $0.isComplete }) {
            precondition(tool.isComplete && tool.website?.scheme == "https")
            let command = await service.proposedInstallCommand(definition: tool, packageManagers: [PackageManagerInfo(id: "homebrew", name: "Homebrew", isInstalled: true, path: nil, version: nil)], pathEnvironment: path)
            precondition(command?.arguments == ["install", HomebrewBootstrap.formula(for: tool)!])
        }
        let unsupported = await service.proposedUpdateCommand(definition: definition, installSource: .unknown, pathEnvironment: path)
        precondition(unsupported == nil)
        let missing = await service.proposedInstallCommand(definition: definition, packageManagers: [], pathEnvironment: path)
        precondition(missing == nil)
        // Exercise the generated script without downloading or installing anything.
        let bootstrap = HomebrewBootstrap.script(formula: "opencode", directory: directory)
        let scriptURL = directory.appendingPathComponent("bootstrap.sh")
        let fakeBrew = HomebrewBootstrap.quote(directory.appendingPathComponent("brew").path)
        let successScript = bootstrap.replacingOccurrences(of: "command -v brew", with: "true")
            .replacingOccurrences(of: "brew install", with: fakeBrew + " install")
        try successScript.write(to: scriptURL, atomically: true, encoding: .utf8)
        let setupSuccess = try await CommandRunner.shared.run(executable: URL(fileURLWithPath: "/bin/bash"), arguments: [scriptURL.path])
        precondition(setupSuccess.succeeded && setupSuccess.stdout.contains("opencode"))
        let statusURL = directory.appendingPathComponent("status")
        let successStatus = try String(contentsOf: statusURL, encoding: .utf8)
        precondition(successStatus.trimmingCharacters(in: .whitespacesAndNewlines) == "0")
        let failureScript = bootstrap.replacingOccurrences(of: "command -v brew", with: "false")
            .replacingOccurrences(of: "/usr/bin/curl", with: "/usr/bin/false")
        try failureScript.write(to: scriptURL, atomically: true, encoding: .utf8)
        let setupFailure = try await CommandRunner.shared.run(executable: URL(fileURLWithPath: "/bin/bash"), arguments: [scriptURL.path])
        precondition(!setupFailure.succeeded && !setupFailure.stdout.contains("Installation complete."))
        let failureStatus = try String(contentsOf: statusURL, encoding: .utf8)
        precondition(failureStatus.trimmingCharacters(in: .whitespacesAndNewlines) != "0")
        let failed = try await CommandRunner.shared.run(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "printf failure >&2; exit 7"])
        precondition(!failed.succeeded && failed.exitCode == 7 && failed.stderr == "failure")
        print("PASS: four install/update managers, missing prerequisites, unsupported source, stdout/stderr and nonzero exit")
    }
}
