import Foundation

struct CommandResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
    let duration: TimeInterval
    let wasCancelled: Bool

    var succeeded: Bool { exitCode == 0 && !wasCancelled }
}

enum CommandRunnerError: LocalizedError {
    case executableNotFound(String)
    case failedToLaunch(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let path):
            return "Executable not found: \(path)"
        case .failedToLaunch(let reason):
            return "Failed to launch process: \(reason)"
        }
    }
}
