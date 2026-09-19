import Darwin
import Foundation
import OSLog

/// Centralized safe command runner. Never blocks the main thread; always times out.
actor CommandRunner {
    static let shared = CommandRunner()

    private let logger = Logger(subsystem: "com.harnessmanager.app", category: "CommandRunner")
    private var logEntries: [CommandLogEntry] = []

    struct CommandLogEntry: Identifiable, Sendable {
        let id = UUID()
        let executable: String
        let arguments: [String]
        let exitCode: Int32
        let duration: TimeInterval
        let timestamp: Date
    }

    func recentLogs(limit: Int = 50) -> [CommandLogEntry] {
        Array(logEntries.suffix(limit).reversed())
    }

    func clearLogs() {
        logEntries.removeAll()
    }

    func run(
        executable: URL,
        arguments: [String],
        environment: [String: String] = [:],
        workingDirectory: URL? = nil,
        timeout: TimeInterval? = 8
    ) async throws -> CommandResult {
        let path = executable.path
        guard FileManager.default.isExecutableFile(atPath: path) || FileManager.default.fileExists(atPath: path) else {
            throw CommandRunnerError.executableNotFound(path)
        }

        // Run Process work on a dedicated background queue so pipe I/O never sits on cooperators that
        // the UI / MainActor might contend with.
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try Self.runProcessBlocking(
                        executable: executable,
                        arguments: arguments,
                        environment: environment,
                        workingDirectory: workingDirectory,
                        timeout: timeout ?? 8
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func runStreaming(
        executable: URL,
        arguments: [String],
        environment: [String: String] = [:],
        workingDirectory: URL? = nil,
        onOutput: @Sendable @escaping (String) -> Void
    ) async throws -> CommandResult {
        try await run(
            executable: executable,
            arguments: arguments,
            environment: environment,
            workingDirectory: workingDirectory,
            timeout: 600
        )
    }

    nonisolated static func resolveExecutable(named name: String, pathEnvironment: String) -> URL? {
        let fm = FileManager.default
        for component in pathEnvironment.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(component)).appendingPathComponent(name)
            if fm.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    // MARK: - Blocking helper (background queue only)

    nonisolated private static func runProcessBlocking(
        executable: URL,
        arguments: [String],
        environment: [String: String],
        workingDirectory: URL?,
        timeout: TimeInterval
    ) throws -> CommandResult {
        let start = Date()
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice

        if let workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "dumb"
        env.removeValue(forKey: "TERM_PROGRAM")
        for (key, value) in environment {
            env[key] = value
        }
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdoutBox = DataBox()
        let stderrBox = DataBox()
        let group = DispatchGroup()

        group.enter()
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                group.leave()
            } else {
                stdoutBox.append(data)
            }
        }

        group.enter()
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                group.leave()
            } else {
                stderrBox.append(data)
            }
        }

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            throw CommandRunnerError.failedToLaunch(error.localizedDescription)
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        var cancelled = false
        if process.isRunning {
            cancelled = true
            process.terminate()
            let killDeadline = Date().addingTimeInterval(0.5)
            while process.isRunning, Date() < killDeadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
        }

        // Wait briefly for pipe EOF handlers; don't hang forever.
        _ = group.wait(timeout: .now() + 0.4)
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        let duration = Date().timeIntervalSince(start)
        let code: Int32 = cancelled && process.terminationStatus == 0 ? 124 : process.terminationStatus

        return CommandResult(
            stdout: String(data: stdoutBox.data, encoding: .utf8) ?? "",
            stderr: String(data: stderrBox.data, encoding: .utf8) ?? "",
            exitCode: code,
            duration: duration,
            wasCancelled: cancelled
        )
    }
}

private final class DataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    var data: Data {
        lock.lock(); defer { lock.unlock() }
        return storage
    }

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock(); storage.append(data); lock.unlock()
    }
}
