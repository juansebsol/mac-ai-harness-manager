import Foundation

struct DetectedProcess: Identifiable, Hashable, Sendable {
    let id: Int32
    let pid: Int32
    let executableName: String
    let harnessId: String?
    let harnessName: String?
    let cpuPercent: Double
    let memoryBytes: UInt64
    let runtimeSeconds: TimeInterval
    let workingDirectory: String?
    let projectName: String?

    var displayMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryBytes), countStyle: .memory)
    }

    var displayRuntime: String {
        let total = Int(runtimeSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "\(total)s"
    }

    var displayCPU: String {
        String(format: "%.0f%%", cpuPercent)
    }
}

struct CodingProject: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let path: String
    var gitBranch: String?
    var activeHarnessId: String?
    var activeHarnessName: String?
    var lastOpened: Date?
    var markers: [String]
}
