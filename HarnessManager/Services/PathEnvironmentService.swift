import Foundation
import OSLog

/// Resolves PATH without blocking the UI.
actor PathEnvironmentService {
    static let shared = PathEnvironmentService()

    private let logger = Logger(subsystem: "com.harnessmanager.app", category: "PathEnvironment")
    private var cachedPATH: String?
    private var cachedAt: Date?

    static let wellKnownBinaryDirectories: [String] = [
        "/opt/homebrew/bin",
        "/opt/homebrew/sbin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin",
        "\(NSHomeDirectory())/.local/bin",
        "\(NSHomeDirectory())/.npm-global/bin",
        "\(NSHomeDirectory())/Library/pnpm",
        "\(NSHomeDirectory())/.bun/bin",
        "\(NSHomeDirectory())/.cargo/bin"
    ]

    /// Instant — no subprocess. Use for first paint.
    func fastPATH(additionalPaths: [String] = []) -> String {
        merge(
            path: ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin",
            extras: Self.wellKnownBinaryDirectories + additionalPaths
        )
    }

    func currentPATH(additionalPaths: [String] = []) async -> String {
        if let cachedPATH, let cachedAt, Date().timeIntervalSince(cachedAt) < 300 {
            return merge(path: cachedPATH, extras: additionalPaths)
        }

        let baseline = fastPATH(additionalPaths: additionalPaths)

        if let shellPATH = await readLoginShellPATH() {
            let merged = merge(path: shellPATH, extras: Self.wellKnownBinaryDirectories + additionalPaths)
            cachedPATH = merged
            cachedAt = Date()
            return merge(path: merged, extras: additionalPaths)
        }

        cachedPATH = baseline
        cachedAt = Date()
        return baseline
    }

    func invalidate() {
        cachedPATH = nil
        cachedAt = nil
    }

    private func readLoginShellPATH() async -> String? {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let shellURL = URL(fileURLWithPath: shell)
        guard FileManager.default.isExecutableFile(atPath: shellURL.path) else {
            return nil
        }

        do {
            let result = try await CommandRunner.shared.run(
                executable: shellURL,
                arguments: ["-lc", "printf '%s' \"$PATH\""],
                timeout: 2
            )
            let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return path.isEmpty ? nil : path
        } catch {
            logger.error("Failed to read login shell PATH: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func merge(path: String, extras: [String]) -> String {
        var seen = Set<String>()
        var ordered: [String] = []
        for item in path.split(separator: ":").map(String.init) + extras.map({ ($0 as NSString).expandingTildeInPath }) {
            guard !item.isEmpty, !seen.contains(item) else { continue }
            seen.insert(item)
            ordered.append(item)
        }
        return ordered.joined(separator: ":")
    }
}
