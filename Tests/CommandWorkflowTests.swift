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
        let unsupported = await service.proposedUpdateCommand(definition: definition, installSource: .unknown, pathEnvironment: path)
        precondition(unsupported == nil)
        let missing = await service.proposedInstallCommand(definition: definition, packageManagers: [], pathEnvironment: path)
        precondition(missing == nil)
        let failed = try await CommandRunner.shared.run(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "printf failure >&2; exit 7"])
        precondition(!failed.succeeded && failed.exitCode == 7 && failed.stderr == "failure")
        print("PASS: four install/update managers, missing prerequisites, unsupported source, stdout/stderr and nonzero exit")
    }
}
