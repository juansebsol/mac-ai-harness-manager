import Foundation

enum MCPTransport: String, Codable, Hashable, Sendable {
    case stdio
    case sse
    case http
    case unknown

    var displayName: String {
        switch self {
        case .stdio: return "stdio"
        case .sse: return "SSE"
        case .http: return "HTTP"
        case .unknown: return "Unknown"
        }
    }
}

enum MCPServerStatus: String, Codable, Hashable, Sendable {
    case configured
    case running
    case error
    case unknown

    var displayName: String {
        switch self {
        case .configured: return "Configured"
        case .running: return "Running"
        case .error: return "Error"
        case .unknown: return "Unknown"
        }
    }
}

struct MCPServer: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let command: String?
    let args: [String]
    let transport: MCPTransport
    let sourceHarnesses: [String]
    let configPath: String?
    var status: MCPServerStatus

    /// Merge key for deduplicating the same server discovered in multiple harness configs.
    var mergeKey: String {
        let cmd = (command ?? "").lowercased()
        let joinedArgs = args.joined(separator: " ").lowercased()
        return "\(name.lowercased())|\(cmd)|\(joinedArgs)|\(transport.rawValue)"
    }

    func merging(with other: MCPServer) -> MCPServer {
        var harnesses = Set(sourceHarnesses)
        harnesses.formUnion(other.sourceHarnesses)
        let preferredStatus: MCPServerStatus = {
            if status == .error || other.status == .error { return .error }
            if status == .running || other.status == .running { return .running }
            if status == .configured || other.status == .configured { return .configured }
            return .unknown
        }()
        return MCPServer(
            id: id,
            name: name,
            command: command ?? other.command,
            args: args.isEmpty ? other.args : args,
            transport: transport == .unknown ? other.transport : transport,
            sourceHarnesses: harnesses.sorted(),
            configPath: configPath ?? other.configPath,
            status: preferredStatus
        )
    }
}
