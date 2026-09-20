import Foundation

struct DiagnosticsEngine {
    func run(for snapshot: HarnessSnapshot, definition: HarnessDefinition) async -> [DiagnosticResult] {
        var checks: [any DiagnosticCheck] = [
            InstalledCheck(snapshot: snapshot),
            BinaryExecutableCheck(snapshot: snapshot),
            VersionDetectedCheck(snapshot: snapshot),
            AuthConfigCheck(snapshot: snapshot, definition: definition),
            GitAvailableCheck(),
            NodeAvailableCheck()
        ]

        if definition.id == "claude-code" || definition.id == "cursor" {
            checks.append(SkillsCountCheck(definition: definition))
            checks.append(MCPCountCheck(definition: definition))
        }

        if snapshot.updateStatus == .updateAvailable {
            checks.append(UpdateBehindCheck(snapshot: snapshot))
        }

        if !definition.isComplete {
            checks.append(IncompleteDefinitionCheck())
        }

        var results: [DiagnosticResult] = []
        for check in checks {
            results.append(await check.run())
        }
        return results
    }
}

struct InstalledCheck: DiagnosticCheck {
    let snapshot: HarnessSnapshot
    var name: String { "Installed" }
    func run() async -> DiagnosticResult {
        if snapshot.isInstalled {
            return DiagnosticResult(name: name, severity: .pass, message: "Harness is installed on this Mac")
        }
        return DiagnosticResult(name: name, severity: .error, message: "Harness was not detected")
    }
}

struct BinaryExecutableCheck: DiagnosticCheck {
    let snapshot: HarnessSnapshot
    var name: String { "Binary executable" }
    func run() async -> DiagnosticResult {
        guard let path = snapshot.binaryPath else {
            if snapshot.applicationPath != nil {
                return DiagnosticResult(name: name, severity: .informational, message: "macOS application detected (no CLI binary required)")
            }
            return DiagnosticResult(name: name, severity: .warning, message: "No CLI binary found")
        }
        if FileManager.default.isExecutableFile(atPath: path) {
            return DiagnosticResult(name: name, severity: .pass, message: path)
        }
        return DiagnosticResult(name: name, severity: .error, message: "Binary exists but is not executable")
    }
}

struct VersionDetectedCheck: DiagnosticCheck {
    let snapshot: HarnessSnapshot
    var name: String { "Version detected" }
    func run() async -> DiagnosticResult {
        if let version = snapshot.installedVersion {
            return DiagnosticResult(name: name, severity: .pass, message: version)
        }
        if snapshot.applicationPath != nil {
            return DiagnosticResult(name: name, severity: .informational, message: "Application install — CLI version not queried")
        }
        return DiagnosticResult(name: name, severity: .warning, message: "Could not detect version")
    }
}

struct AuthConfigCheck: DiagnosticCheck {
    let snapshot: HarnessSnapshot
    let definition: HarnessDefinition
    var name: String { "Authentication configuration" }
    func run() async -> DiagnosticResult {
        let authRelated = snapshot.configItems.filter {
            $0.exists && (
                $0.label.lowercased().contains("auth")
                    || $0.label.lowercased().contains("config")
                    || $0.path.lowercased().contains("auth")
                    || $0.kind == .directory
            )
        }
        if !authRelated.isEmpty {
            return DiagnosticResult(
                name: name,
                severity: .pass,
                message: "Configuration appears present (secrets not inspected)"
            )
        }
        // Provider env presence without values
        for providerId in definition.providerIds {
            if let provider = ProviderCatalog.definition(for: providerId) {
                for key in provider.environmentVariables {
                    if ProcessInfo.processInfo.environment[key] != nil {
                        return DiagnosticResult(
                            name: name,
                            severity: .pass,
                            message: "\(key) — detected (value hidden)"
                        )
                    }
                }
            }
        }
        return DiagnosticResult(
            name: name,
            severity: .warning,
            message: "No authentication configuration detected"
        )
    }
}

struct GitAvailableCheck: DiagnosticCheck {
    var name: String { "Git available" }
    func run() async -> DiagnosticResult {
        let git = URL(fileURLWithPath: "/usr/bin/git")
        if FileManager.default.isExecutableFile(atPath: git.path) {
            return DiagnosticResult(name: name, severity: .pass, message: git.path)
        }
        return DiagnosticResult(name: name, severity: .warning, message: "Git not found at /usr/bin/git")
    }
}

struct NodeAvailableCheck: DiagnosticCheck {
    var name: String { "Node installed" }
    func run() async -> DiagnosticResult {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/opt/homebrew/bin"
        if let node = CommandRunner.resolveExecutable(named: "node", pathEnvironment: path) {
            return DiagnosticResult(name: name, severity: .pass, message: node.path)
        }
        return DiagnosticResult(name: name, severity: .informational, message: "Node.js not found in PATH")
    }
}

struct SkillsCountCheck: DiagnosticCheck {
    let definition: HarnessDefinition
    var name: String { "Skills detected" }
    func run() async -> DiagnosticResult {
        let skills = await SkillsDiscoveryService.shared.discover(definitions: [definition])
        let count = skills.count
        if count > 0 {
            return DiagnosticResult(name: name, severity: .pass, message: "\(count) skill(s) detected")
        }
        return DiagnosticResult(name: name, severity: .informational, message: "No skills detected")
    }
}

struct MCPCountCheck: DiagnosticCheck {
    let definition: HarnessDefinition
    var name: String { "MCP servers detected" }
    func run() async -> DiagnosticResult {
        let servers = await MCPDiscoveryService.shared.discover(definitions: [definition])
        let count = servers.count
        if count > 0 {
            return DiagnosticResult(name: name, severity: .pass, message: "\(count) MCP server(s) detected")
        }
        return DiagnosticResult(name: name, severity: .informational, message: "No MCP servers detected")
    }
}

struct UpdateBehindCheck: DiagnosticCheck {
    let snapshot: HarnessSnapshot
    var name: String { "Update status" }
    func run() async -> DiagnosticResult {
        let installed = snapshot.installedVersion ?? "?"
        let latest = snapshot.latestVersion ?? "?"
        return DiagnosticResult(
            name: name,
            severity: .warning,
            message: "Installed \(installed); latest \(latest)"
        )
    }
}

struct IncompleteDefinitionCheck: DiagnosticCheck {
    var name: String { "Definition completeness" }
    func run() async -> DiagnosticResult {
        DiagnosticResult(
            name: name,
            severity: .informational,
            message: "Harness definition is incomplete — detection may be limited"
        )
    }
}
