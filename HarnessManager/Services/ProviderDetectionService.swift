import Foundation
import OSLog

actor ProviderDetectionService {
    static let shared = ProviderDetectionService()

    private let logger = Logger(subsystem: "com.harnessmanager.app", category: "Providers")

    func detect(harnesses: [HarnessSnapshot], pathEnvironment: String) async -> [ProviderStatus] {
        // Read shell env for presence-only checks (values never stored/displayed).
        let envKeys = await loginShellEnvironmentKeys()

        return ProviderCatalog.all.map { provider in
            var signals: [String] = []

            for key in provider.environmentVariables {
                if ProcessInfo.processInfo.environment[key] != nil || envKeys.contains(key) {
                    // Presence only — never read or display the value.
                    signals.append("\(key) — detected")
                }
            }

            for hint in provider.configHints {
                let path = (hint as NSString).expandingTildeInPath
                if FileManager.default.fileExists(atPath: path) {
                    signals.append("Config path found")
                    break
                }
            }

            // Anthropic/Claude: ~/.claude presence without reading secrets
            if provider.id == "anthropic" {
                let claude = (NSHomeDirectory() as NSString).appendingPathComponent(".claude")
                if FileManager.default.fileExists(atPath: claude) {
                    if !signals.contains(where: { $0.contains("Config") }) {
                        signals.append("Claude config directory — detected")
                    }
                }
            }

            let harnessIds = harnesses
                .filter { $0.isInstalled && $0.providerIds.contains(provider.id) }
                .map(\.definitionId)

            return ProviderStatus(
                id: provider.id,
                name: provider.name,
                isConfigured: !signals.isEmpty,
                detectedSignals: signals,
                harnessIds: harnessIds
            )
        }
    }

    /// Collect environment variable *names* from the process environment only.
    /// Avoid spawning a login shell here — that was hanging GUI launches.
    private func loginShellEnvironmentKeys() async -> Set<String> {
        Set(ProcessInfo.processInfo.environment.keys)
    }
}
