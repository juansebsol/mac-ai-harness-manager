import AppKit
import Foundation
import OSLog

protocol TerminalLauncher: Sendable {
    func launch(command: String, workingDirectory: URL) async throws
}

enum TerminalLauncherError: LocalizedError {
    case unsupportedTerminal(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedTerminal(let name):
            return "Preferred terminal unavailable: \(name)"
        case .failed(let reason):
            return reason
        }
    }
}

struct SystemTerminalLauncher: TerminalLauncher {
    let preference: PreferredTerminal

    private var logger: Logger { Logger(subsystem: "com.harnessmanager.app", category: "Terminal") }

    func launch(command: String, workingDirectory: URL) async throws {
        let resolved = resolveTerminal()
        switch resolved {
        case .terminal:
            try await launchTerminalApp(command: command, workingDirectory: workingDirectory)
        case .iterm:
            try await launchITerm(command: command, workingDirectory: workingDirectory)
        case .warp:
            try openApp(bundleId: "dev.warp.Warp-Stable", fallback: "dev.warp.Warp", directory: workingDirectory)
        case .ghostty:
            try openApp(bundleId: "com.mitchellh.ghostty", fallback: nil, directory: workingDirectory)
        case .automatic:
            try await launchTerminalApp(command: command, workingDirectory: workingDirectory)
        }
    }

    private func resolveTerminal() -> PreferredTerminal {
        switch preference {
        case .automatic:
            if NSWorkspace.shared.urlForApplication(withBundleIdentifier: "dev.warp.Warp-Stable") != nil
                || NSWorkspace.shared.urlForApplication(withBundleIdentifier: "dev.warp.Warp") != nil {
                return .warp
            }
            if NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2") != nil {
                return .iterm
            }
            if NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.mitchellh.ghostty") != nil {
                return .ghostty
            }
            return .terminal
        default:
            return preference
        }
    }

    private func launchTerminalApp(command: String, workingDirectory: URL) async throws {
        // Open Terminal.app at the directory; run command via open + osascript only when needed.
        // Prefer `open -a Terminal <dir>` which does not require Automation for mere directory open.
        let open = URL(fileURLWithPath: "/usr/bin/open")
        _ = try await CommandRunner.shared.run(
            executable: open,
            arguments: ["-a", "Terminal", workingDirectory.path],
            timeout: 10
        )

        // Best-effort: ask Terminal to run the command. Requires Automation permission.
        // We explain this in Settings / confirmation UI before relying on it.
        let escapedDir = workingDirectory.path.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let escapedCmd = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "Terminal"
          activate
          do script "cd \\"\(escapedDir)\\" && \(escapedCmd)"
        end tell
        """

        let osascript = URL(fileURLWithPath: "/usr/bin/osascript")
        _ = try? await CommandRunner.shared.run(
            executable: osascript,
            arguments: ["-e", script],
            timeout: 15
        )
    }

    private func launchITerm(command: String, workingDirectory: URL) async throws {
        let escapedDir = workingDirectory.path.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let escapedCmd = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "iTerm"
          activate
          create window with default profile
          tell current session of current window
            write text "cd \\"\(escapedDir)\\" && \(escapedCmd)"
          end tell
        end tell
        """
        let osascript = URL(fileURLWithPath: "/usr/bin/osascript")
        let result = try await CommandRunner.shared.run(
            executable: osascript,
            arguments: ["-e", script],
            timeout: 15
        )
        if !result.succeeded {
            throw TerminalLauncherError.failed(result.stderr.isEmpty ? "iTerm launch failed" : result.stderr)
        }
    }

    private func openApp(bundleId: String, fallback: String?, directory: URL) throws {
        let workspace = NSWorkspace.shared
        var appURL = workspace.urlForApplication(withBundleIdentifier: bundleId)
        if appURL == nil, let fallback {
            appURL = workspace.urlForApplication(withBundleIdentifier: fallback)
        }
        guard let appURL else {
            throw TerminalLauncherError.unsupportedTerminal(bundleId)
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        workspace.open([directory], withApplicationAt: appURL, configuration: config)
    }
}
