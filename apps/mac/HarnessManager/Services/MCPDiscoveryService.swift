import Foundation
import OSLog

actor MCPDiscoveryService {
    static let shared = MCPDiscoveryService()

    private let logger = Logger(subsystem: "com.harnessmanager.app", category: "MCP")

    func discover(definitions: [HarnessDefinition] = HarnessRegistry.all) async -> [MCPServer] {
        var servers: [String: MCPServer] = [:]

        for definition in definitions {
            for spec in definition.configPaths where spec.label.lowercased().contains("mcp") || spec.path.lowercased().contains("mcp") {
                let url = spec.expandedURL()
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                let parsed = parseMCPConfig(at: url, harnessId: definition.id, harnessName: definition.name)
                for server in parsed {
                    if let existing = servers[server.mergeKey] {
                        servers[server.mergeKey] = existing.merging(with: server)
                    } else {
                        servers[server.mergeKey] = server
                    }
                }
            }

            // Also check common well-known MCP config files for this harness
            for candidate in wellKnownMCPPaths(for: definition) {
                guard FileManager.default.fileExists(atPath: candidate.path) else { continue }
                let parsed = parseMCPConfig(at: candidate, harnessId: definition.id, harnessName: definition.name)
                for server in parsed {
                    if let existing = servers[server.mergeKey] {
                        servers[server.mergeKey] = existing.merging(with: server)
                    } else {
                        servers[server.mergeKey] = server
                    }
                }
            }
        }

        return Array(servers.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func wellKnownMCPPaths(for definition: HarnessDefinition) -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch definition.id {
        case "claude-code":
            return [
                home.appendingPathComponent(".claude/mcp.json"),
                home.appendingPathComponent(".claude.json")
            ]
        case "cursor":
            return [home.appendingPathComponent(".cursor/mcp.json")]
        case "codex":
            return [home.appendingPathComponent(".codex/config.toml")]
        case "opencode":
            return [
                home.appendingPathComponent(".config/opencode/config.json"),
                home.appendingPathComponent(".opencode/config.json")
            ]
        default:
            return []
        }
    }

    private func parseMCPConfig(at url: URL, harnessId: String, harnessName: String) -> [MCPServer] {
        let ext = url.pathExtension.lowercased()
        if ext == "json" || url.lastPathComponent.hasSuffix(".json") {
            return parseJSONMCP(at: url, harnessId: harnessId, harnessName: harnessName)
        }
        if ext == "toml" {
            return parseTOMLMCPHints(at: url, harnessId: harnessId, harnessName: harnessName)
        }
        return []
    }

    private func parseJSONMCP(at url: URL, harnessId: String, harnessName: String) -> [MCPServer] {
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }

        // Support shapes: { "mcpServers": { ... } } and { "servers": { ... } }
        let root = (obj["mcpServers"] as? [String: Any])
            ?? (obj["servers"] as? [String: Any])
            ?? (obj["mcp"] as? [String: Any])
            ?? [:]

        // Claude root settings sometimes nest mcpServers
        let serversDict: [String: Any]
        if !root.isEmpty {
            serversDict = root
        } else if let nested = obj["mcpServers"] as? [String: Any] {
            serversDict = nested
        } else {
            serversDict = [:]
        }

        var results: [MCPServer] = []
        for (name, value) in serversDict {
            guard let config = value as? [String: Any] else { continue }
            let command = config["command"] as? String
            let args = (config["args"] as? [String]) ?? []
            let transport: MCPTransport = {
                if let t = config["transport"] as? String {
                    return MCPTransport(rawValue: t.lowercased()) ?? .unknown
                }
                if config["url"] != nil { return .http }
                if command != nil { return .stdio }
                return .unknown
            }()

            // Never capture env secrets — only note presence.
            results.append(
                MCPServer(
                    id: "\(harnessId):\(name)",
                    name: name,
                    command: command,
                    args: args,
                    transport: transport,
                    sourceHarnesses: [harnessName],
                    configPath: url.path,
                    status: .configured
                )
            )
        }
        return results
    }

    private func parseTOMLMCPHints(at url: URL, harnessId: String, harnessName: String) -> [MCPServer] {
        // Lightweight TOML scan for mcp_servers / [mcp_servers.NAME] without a full parser.
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var results: [MCPServer] = []
        let pattern = #"\[mcp_servers\.([^\]]+)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match, let nameRange = Range(match.range(at: 1), in: text) else { return }
            let name = String(text[nameRange])
            results.append(
                MCPServer(
                    id: "\(harnessId):\(name)",
                    name: name,
                    command: nil,
                    args: [],
                    transport: .stdio,
                    sourceHarnesses: [harnessName],
                    configPath: url.path,
                    status: .configured
                )
            )
        }
        return results
    }
}
