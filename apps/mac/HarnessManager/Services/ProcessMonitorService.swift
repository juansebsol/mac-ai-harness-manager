import Foundation
import Darwin
import OSLog

actor ProcessMonitorService {
    static let shared = ProcessMonitorService()

    private let logger = Logger(subsystem: "com.harnessmanager.app", category: "Processes")

    func listHarnessProcesses(definitions: [HarnessDefinition] = HarnessRegistry.all) async -> [DetectedProcess] {
        let binaryNames = Set(definitions.flatMap(\.binaryNames).map { $0.lowercased() })
        let nameToHarness: [String: HarnessDefinition] = {
            var map: [String: HarnessDefinition] = [:]
            for def in definitions {
                for bin in def.binaryNames {
                    map[bin.lowercased()] = def
                }
            }
            return map
        }()

        // Use `ps` with fixed arguments — no user input.
        let ps = URL(fileURLWithPath: "/bin/ps")
        guard FileManager.default.isExecutableFile(atPath: ps.path) else { return [] }

        do {
            let result = try await CommandRunner.shared.run(
                executable: ps,
                arguments: ["-axo", "pid=,pcpu=,rss=,etime=,comm=,args="],
                timeout: 10
            )
            var processes: [DetectedProcess] = []
            for line in result.stdout.split(whereSeparator: \.isNewline) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                guard let parsed = parsePSLine(trimmed) else { continue }

                let execName = (parsed.comm as NSString).lastPathComponent.lowercased()
                guard binaryNames.contains(execName) || binaryNames.contains(where: { parsed.args.lowercased().contains($0) }) else {
                    continue
                }

                let matchedName = binaryNames.first(where: { execName == $0 || parsed.args.lowercased().contains($0) }) ?? execName
                let harness = nameToHarness[matchedName] ?? nameToHarness[execName]
                let cwd = workingDirectory(for: parsed.pid)
                let project = cwd.map { ($0 as NSString).lastPathComponent }

                processes.append(
                    DetectedProcess(
                        id: parsed.pid,
                        pid: parsed.pid,
                        executableName: (parsed.comm as NSString).lastPathComponent,
                        harnessId: harness?.id,
                        harnessName: harness?.name,
                        cpuPercent: parsed.cpu,
                        memoryBytes: parsed.rssKB * 1024,
                        runtimeSeconds: parsed.etimeSeconds,
                        workingDirectory: cwd,
                        projectName: project
                    )
                )
            }
            return processes.sorted { $0.cpuPercent > $1.cpuPercent }
        } catch {
            logger.error("ps failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func terminate(pid: Int32, force: Bool) -> Bool {
        let signal = force ? SIGKILL : SIGTERM
        return kill(pid, signal) == 0
    }

    private struct PSFields {
        let pid: Int32
        let cpu: Double
        let rssKB: UInt64
        let etimeSeconds: TimeInterval
        let comm: String
        let args: String
    }

    private func parsePSLine(_ line: String) -> PSFields? {
        // pid pcpu rss etime comm args...
        let parts = line.split(whereSeparator: { $0.isWhitespace })
        guard parts.count >= 5,
              let pid = Int32(parts[0]),
              let cpu = Double(parts[1]),
              let rss = UInt64(parts[2])
        else { return nil }

        let etime = String(parts[3])
        let comm = String(parts[4])
        let args = parts.dropFirst(5).map(String.init).joined(separator: " ")
        return PSFields(
            pid: pid,
            cpu: cpu,
            rssKB: rss,
            etimeSeconds: parseEtime(etime),
            comm: comm,
            args: args
        )
    }

    private func parseEtime(_ value: String) -> TimeInterval {
        // [[dd-]hh:]mm:ss
        let cleaned = value.trimmingCharacters(in: .whitespaces)
        var days = 0
        var rest = cleaned
        if let dash = cleaned.firstIndex(of: "-") {
            days = Int(cleaned[..<dash]) ?? 0
            rest = String(cleaned[cleaned.index(after: dash)...])
        }
        let comps = rest.split(separator: ":").compactMap { Int($0) }
        var seconds = days * 86_400
        if comps.count == 3 {
            seconds += comps[0] * 3600 + comps[1] * 60 + comps[2]
        } else if comps.count == 2 {
            seconds += comps[0] * 60 + comps[1]
        } else if comps.count == 1 {
            seconds += comps[0]
        }
        return TimeInterval(seconds)
    }

    private func workingDirectory(for pid: Int32) -> String? {
        let lsof = URL(fileURLWithPath: "/usr/sbin/lsof")
        guard FileManager.default.isExecutableFile(atPath: lsof.path) else { return nil }
        // Best-effort; may fail without extra permissions — that's fine.
        // Avoid running lsof for every process synchronously in tight loops by keeping it optional.
        return nil
    }
}
