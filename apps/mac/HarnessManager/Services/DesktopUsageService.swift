// Provider protocols adapted from OpenUsage (MIT, Copyright 2026 Robin Ebers).
// See Resources/OpenUsage-LICENSE.txt. These endpoints are undocumented and may change.
import Foundation
import CryptoKit
import Security
import LocalAuthentication
import SQLite3

struct DesktopUsageMetric: Identifiable, Sendable {
    enum Unit: Sendable { case percent, dollars, requests, currency(String) }
    let id: String
    let title: String
    let used: Double
    let limit: Double?
    let unit: Unit
    var resetsAt: Date?
    var valueLabel: String? = nil
    var remaining: Double? { limit.map { max(0, $0 - used) } }
    func formatted(_ value: Double) -> String {
        switch unit {
        case .percent: return value.formatted(.number.precision(.fractionLength(0...1))) + "%"
        case .currency(let code): return value.formatted(.currency(code: code))
        case .dollars: return value.formatted(.currency(code: "USD"))
        case .requests: return value.formatted(.number.precision(.fractionLength(0)))
        }
    }
}

struct DesktopUsageSnapshot: Sendable {
    var metrics: [DesktopUsageMetric]
    let source: String
    var note: String?
    var fetchedAt = Date()
}

enum DesktopUsageParser {
    static func object(_ data: Data) throws -> [String: Any] {
        guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageFailure.unavailable("The provider returned an unreadable usage response.")
        }
        return value
    }
    static func number(_ value: Any?) -> Double? {
        guard !(value is NSNull) else { return nil }
        if let value = value as? NSNumber, CFGetTypeID(value) == CFBooleanGetTypeID() { return nil }
        let result = (value as? NSNumber)?.doubleValue ?? (value as? String).flatMap(Double.init)
        return result.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
    }
    static func date(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }

    static func cursor(primary: Data?, summary: Data?, requests: Data?) throws -> DesktopUsageSnapshot {
        let primary = primary.flatMap { try? object($0) } ?? [:]
        let summary = summary.flatMap { try? object($0) } ?? [:]
        let requests = requests.flatMap { try? object($0) } ?? [:]
        if primary["enabled"] as? Bool == false {
            throw UsageFailure.unavailable("Cursor reports no active usage subscription for this account.")
        }
        let reset = number(primary["billingCycleEnd"]).map { Date(timeIntervalSince1970: $0 / 1000) }
            ?? date(summary["billingCycleEnd"])
        let individual = summary["individualUsage"] as? [String: Any] ?? [:]
        let team = summary["teamUsage"] as? [String: Any] ?? [:]
        let plan = primary["planUsage"] as? [String: Any] ?? individual["plan"] as? [String: Any] ?? [:]
        var metrics: [DesktopUsageMetric] = []
        func percent(_ id: String, _ title: String, _ value: Any?) {
            if let used = number(value) {
                metrics.append(.init(id: id, title: title, used: used, limit: 100, unit: .percent, resetsAt: reset))
            }
        }
        if let count = requests["gpt-4"] as? [String: Any], let limit = number(count["maxRequestUsage"]), limit > 0,
           let used = number(count["numRequests"]) ?? number(count["numRequestsTotal"]) {
            metrics.append(.init(id: "plan", title: "Included requests · billing cycle", used: used, limit: limit, unit: .requests, resetsAt: reset))
        } else if number(plan["totalPercentUsed"]) != nil {
            percent("plan", "Plan usage · billing cycle", plan["totalPercentUsed"])
        } else if let limit = number(plan["limit"]), limit > 0,
                  let used = number(plan["totalSpend"]) ?? number(plan["remaining"]).map({ max(0, limit - $0) }) {
            metrics.append(.init(id: "plan", title: "Included usage · billing cycle", used: used / 100, limit: limit / 100, unit: .dollars, resetsAt: reset))
        } else if let overall = individual["overall"] as? [String: Any] ?? team["pooled"] as? [String: Any],
                  let used = number(overall["used"]) {
            metrics.append(.init(id: "plan", title: individual["overall"] == nil ? "Team usage · billing cycle" : "Included usage · billing cycle", used: used / 100, limit: number(overall["limit"]).map { $0 / 100 }, unit: .dollars, resetsAt: reset))
        }
        percent("cursor-models", "Cursor models", plan["autoPercentUsed"])
        percent("other-models", "Other models", plan["apiPercentUsed"])
        if let demand = individual["onDemand"] as? [String: Any] ?? team["onDemand"] as? [String: Any], demand["enabled"] as? Bool != false,
           let used = number(demand["used"]) {
            metrics.append(.init(id: "on-demand", title: individual["onDemand"] == nil ? "Team on-demand spending" : "On-demand spending", used: used / 100, limit: number(demand["limit"]).map { $0 / 100 }, unit: .dollars, resetsAt: reset))
        } else if let spend = primary["spendLimitUsage"] as? [String: Any] {
            let personal = number(spend["individualUsed"]) != nil || number(spend["individualLimit"]) != nil
            let limit = number(spend[personal ? "individualLimit" : "pooledLimit"])
            let used = number(spend[personal ? "individualUsed" : "pooledUsed"])
                ?? limit.flatMap { cap in number(spend[personal ? "individualRemaining" : "pooledRemaining"]).map { max(0, cap - $0) } }
            if let used {
                metrics.append(.init(id: "on-demand", title: personal ? "On-demand spending" : "Team on-demand spending", used: used / 100, limit: limit.map { $0 / 100 }, unit: .dollars, resetsAt: reset))
            }
        }
        guard !metrics.isEmpty else { throw UsageFailure.unavailable("Cursor returned no supported usage fields for this account. Check your dashboard or refresh after updating Cursor.") }
        return .init(metrics: metrics, source: "Cursor dashboard · existing app sign-in", note: "Plan percentages and included spending cover the current billing cycle. On-demand spending is shown separately.")
    }

    /// nil is an unsupported schema; an empty array is an authoritative response with no quotas.
    static func antigravitySummary(_ data: Data) -> [DesktopUsageMetric]? {
        guard let root = try? object(data),
              let groups = ((root["response"] as? [String: Any]) ?? root)["groups"] as? [Any] else { return nil }
        let specs = [("gemini-5h", "Gemini · 5 hours"), ("gemini-weekly", "Gemini · weekly"),
                     ("3p-5h", "Claude & other models · 5 hours"), ("3p-weekly", "Claude & other models · weekly")]
        var found: [String: DesktopUsageMetric] = [:]
        for group in groups {
            for value in (group as? [String: Any])?["buckets"] as? [Any] ?? [] {
                guard let bucket = value as? [String: Any], let id = bucket["bucketId"] as? String,
                      let title = specs.first(where: { $0.0 == id })?.1, found[id] == nil,
                      let remaining = number(bucket["remainingFraction"]), remaining <= 1 else { continue }
                found[id] = .init(id: id, title: title, used: (1 - remaining) * 100, limit: 100, unit: .percent, resetsAt: date(bucket["resetTime"]))
            }
        }
        return specs.compactMap { found[$0.0] }
    }

    static func antigravityLegacy(_ data: Data) -> [DesktopUsageMetric] {
        guard let root = try? object(data) else { return [] }
        let status = root["userStatus"] as? [String: Any] ?? [:]
        let configs = (status["cascadeModelConfigData"] as? [String: Any])?["clientModelConfigs"] as? [[String: Any]]
            ?? root["clientModelConfigs"] as? [[String: Any]]
            ?? (root["models"] as? [String: [String: Any]]).map { Array($0.values) } ?? []
        var pools: [String: DesktopUsageMetric] = [:]
        for model in configs where model["isInternal"] as? Bool != true {
            guard let label = model["label"] as? String ?? model["displayName"] as? String,
                  let quota = model["quotaInfo"] as? [String: Any],
                  let fraction = number(quota["remainingFraction"]), fraction <= 1 else { continue }
            let gemini = label.lowercased().contains("gemini")
            let id = gemini ? "gemini-5h" : "3p-5h"
            let used = (1 - fraction) * 100
            if pools[id] == nil || used > pools[id]!.used {
                pools[id] = .init(id: id, title: gemini ? "Gemini · 5 hours" : "Claude & other models · 5 hours", used: used, limit: 100, unit: .percent, resetsAt: date(quota["resetTime"]))
            }
        }
        return ["gemini-5h", "3p-5h"].compactMap { pools[$0] }
    }

    static func jwt(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var value = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        value += String(repeating: "=", count: (4 - value.count % 4) % 4)
        return Data(base64Encoded: value).flatMap { try? object($0) }
    }
}

enum DesktopUsageCredentials {
    static func keychain(service: String, account: String? = nil) -> String? {
        try? UsageKeychainInteraction.read(service: service, account: account)
    }

    static func cursor() -> (access: String?, refresh: String?) {
        let path = NSHomeDirectory() + "/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
        var database: OpaquePointer?
        defer { if let database { sqlite3_close(database) } }
        var access: String?, refresh: String?
        if sqlite3_open_v2(path, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK {
            sqlite3_busy_timeout(database, 1000)
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            // Only the two auth entries, never the user's workspace or conversation data.
            if sqlite3_prepare_v2(database, "SELECT key, value FROM ItemTable WHERE key IN ('cursorAuth/accessToken', 'cursorAuth/refreshToken')", -1, &statement, nil) == SQLITE_OK {
                while sqlite3_step(statement) == SQLITE_ROW {
                    guard let key = sqlite3_column_text(statement, 0), let value = sqlite3_column_text(statement, 1) else { continue }
                    if String(cString: key) == "cursorAuth/accessToken" { access = String(cString: value) }
                    else { refresh = String(cString: value) }
                }
            }
        }
        // Never combine credentials from potentially different app and CLI accounts.
        if access?.isEmpty == false || refresh?.isEmpty == false { return (access, refresh) }
        return (keychain(service: "cursor-access-token"), keychain(service: "cursor-refresh-token"))
    }

    static func antigravity() async throws -> (access: String?, refresh: String?)? {
        let raw = try await UsageCredentialSession.shared.read("antigravity") {
            try await UsageCredentialReader.read("antigravity") {
                try UsageKeychainInteraction.read(service: "gemini", account: "antigravity")
            }
        }
        guard let raw else { return nil }
        return try antigravityCredential(exitCode: 0, stdout: raw)
    }

    // Only the dedicated Reconnect button can start an interactive Keychain read.
    static func authorizeAntigravity() async throws {
        let result = try await CommandRunner.shared.run(
            executable: URL(fileURLWithPath: "/usr/bin/security"),
            arguments: ["find-generic-password", "-a", "antigravity", "-s", "gemini", "-w"],
            timeout: 60)
        guard let credentials = try antigravityCredential(exitCode: result.exitCode, stdout: result.stdout),
              credentials.access != nil || credentials.refresh != nil else {
            throw UsageFailure.unavailable("No Antigravity sign-in found. Sign in to Antigravity first, then reconnect.")
        }
        await UsageCredentialSession.shared.set("antigravity", value: result.stdout)
    }

    static func antigravityCredential(exitCode: Int32, stdout: String) throws -> (access: String?, refresh: String?)? {
        if exitCode == 44 { return nil } // errSecItemNotFound, as returned by security(1).
        guard exitCode == 0 else {
            throw UsageFailure.unavailable("macOS couldn’t read Antigravity’s saved sign-in. Approve any Keychain access prompt, then refresh. Your Antigravity account has not been disconnected.")
        }
        var text = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("go-keyring-base64:") {
            guard let data = Data(base64Encoded: String(text.dropFirst("go-keyring-base64:".count))), let decoded = String(data: data, encoding: .utf8) else { return nil }
            text = decoded
        }
        guard let root = try? DesktopUsageParser.object(Data(text.utf8)) else { return nil }
        let token = root["token"] as? [String: Any] ?? root
        return (token["access_token"] as? String ?? token["accessToken"] as? String,
                token["refresh_token"] as? String ?? token["refreshToken"] as? String)
    }
}

/// Redirects are never followed with provider credentials. Self-signed TLS is scoped to one
/// discovered language-server port on loopback; all remote provider calls retain system trust.
private final class DesktopUsageTransport: NSObject, URLSessionDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    let loopbackPort: Int?
    init(loopbackPort: Int? = nil) { self.loopbackPort = loopbackPort }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let port = loopbackPort, challenge.protectionSpace.host == "127.0.0.1", challenge.protectionSpace.port == port,
           challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust, let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else { completionHandler(.performDefaultHandling, nil) }
    }
    func send(url: URL, headers: [String: String], body: Data? = nil) async throws -> (Data, Int) {
        var request = URLRequest(url: url)
        request.httpMethod = body == nil ? "GET" : "POST"
        request.httpBody = body
        request.allHTTPHeaderFields = headers
        request.timeoutInterval = loopbackPort == nil ? 12 : 2
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil; config.httpCookieStorage = nil
        config.connectionProxyDictionary = loopbackPort == nil ? nil : [:]
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}

enum CursorUsageClient {
    static func fetch() async throws -> DesktopUsageSnapshot {
        let credentials = try await UsageCredentialReader.read("cursor") { DesktopUsageCredentials.cursor() }
        guard credentials.access?.isEmpty == false || credentials.refresh?.isEmpty == false else {
            throw UsageFailure.unavailable("Sign in to Cursor on this Mac, then refresh. No API key is needed.")
        }
        let http = DesktopUsageTransport()
        var access = credentials.access ?? ""
        func refresh() async throws -> String {
            guard let token = credentials.refresh, !token.isEmpty else { throw expired() }
            let body = try JSONSerialization.data(withJSONObject: ["grant_type": "refresh_token", "client_id": "KbZUR41cY7W6zRSdpSUJ7I7mLYBKOCmB", "refresh_token": token])
            let (data, code) = try await http.send(url: URL(string: "https://api2.cursor.sh/oauth/token")!, headers: ["Content-Type": "application/json"], body: body)
            guard code == 200, let token = (try? DesktopUsageParser.object(data))?["access_token"] as? String, !token.isEmpty else { throw expired() }
            return token // Memory only; never changes Cursor's database or Keychain.
        }
        if access.isEmpty || (DesktopUsageParser.number(DesktopUsageParser.jwt(access)?["exp"]) ?? .greatestFiniteMagnitude) < Date().timeIntervalSince1970 + 30 {
            access = try await refresh()
        }
        func primary(_ token: String) async throws -> (Data, Int) {
            try await http.send(url: URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage")!,
                headers: ["Authorization": "Bearer \(token)", "Content-Type": "application/json", "Connect-Protocol-Version": "1"], body: Data("{}".utf8))
        }
        var result = try await primary(access)
        if result.1 == 401 || result.1 == 403 { access = try await refresh(); result = try await primary(access) }
        if result.1 == 401 || result.1 == 403 { throw expired() }
        var summary: Data?, requests: Data?
        if let sub = DesktopUsageParser.jwt(access)?["sub"] as? String, let user = sub.split(separator: "|").last, !user.isEmpty {
            let cookie = "WorkosCursorSessionToken=\(user)%3A%3A\(access)"
            async let summaryReply = try? http.send(url: URL(string: "https://cursor.com/api/usage-summary")!, headers: ["Cookie": cookie])
            var url = URLComponents(string: "https://cursor.com/api/usage")!
            url.queryItems = [URLQueryItem(name: "user", value: String(user))]
            let requestURL = url.url!
            async let requestReply = try? http.send(url: requestURL, headers: ["Cookie": cookie])
            if let reply = await summaryReply, reply.1 == 200 { summary = reply.0 }
            if let reply = await requestReply, reply.1 == 200 { requests = reply.0 }
        }
        return try DesktopUsageParser.cursor(primary: result.1 == 200 ? result.0 : nil, summary: summary, requests: requests)
    }
    private static func expired() -> UsageFailure { .unavailable("Cursor sign-in expired or couldn’t be refreshed. Open Cursor, sign in again, then refresh here.") }
}

enum AntigravityUsageClient {
    struct Server: Sendable { let pid: Int32; let csrf: String; let extensionPort: Int? }
    static func flag(_ name: String, in command: String) -> String? {
        let words = command.split(whereSeparator: \.isWhitespace).map(String.init)
        for (index, word) in words.enumerated() {
            if word == name && index + 1 < words.count { return words[index + 1] }
            if word.hasPrefix(name + "=") { return String(word.dropFirst(name.count + 1)) }
        }
        return nil
    }
    static func servers(_ output: String) -> [Server] {
        output.split(separator: "\n").compactMap { line in
            let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
            guard parts.count == 2, let pid = Int32(parts[0]) else { return nil }
            let command = String(parts[1]), lower = command.lowercased()
            let marker = flag("--ide_name", in: lower) ?? flag("--app_data_dir", in: lower) ?? flag("--override_ide_name", in: lower)
            let antigravity = marker == "antigravity" || marker == "antigravity-ide" || lower.contains("/antigravity.app/") || lower.contains("/antigravity ide.app/")
            guard antigravity && lower.contains("language_server"), let csrf = flag("--csrf_token", in: command), !csrf.isEmpty else { return nil }
            return Server(pid: pid, csrf: csrf, extensionPort: flag("--extension_server_port", in: command).flatMap(Int.init))
        }
    }
    static func ports(_ output: String) -> [Int] {
        Array(Set(output.split(separator: "\n").filter { $0.hasPrefix("n") }.compactMap { Int($0.split(separator: ":").last ?? "") }.filter { (1...65535).contains($0) })).sorted()
    }
    static func fetch() async throws -> DesktopUsageSnapshot {
        if let local = await local() { return local }
        let credentials = try await DesktopUsageCredentials.antigravity()
        guard let credentials else { throw UsageFailure.unavailable("Open Antigravity or Antigravity IDE and sign in, then refresh. Both apps use the same quota pools.") }
        let http = DesktopUsageTransport()
        let cache = AntigravityTokenCache()
        var cacheWarning: String?
        var token = credentials.refresh.flatMap { cache.load(source: $0) } ?? credentials.access ?? ""
        var outcome = token.isEmpty ? (snapshot: Optional<DesktopUsageSnapshot>.none, authFailed: true) : await cloud(token, http: http)
        if outcome.snapshot == nil, outcome.authFailed, let refresh = credentials.refresh, !refresh.isEmpty {
            // Public installed-app OAuth client shipped with Antigravity, documented by OpenUsage.
            var form = URLComponents()
            form.queryItems = [URLQueryItem(name: "client_id", value: "1071006060591-tmhssin2h21lcre235vtolojh4g403ep.apps.googleusercontent.com"),
                URLQueryItem(name: "client_secret", value: "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"),
                URLQueryItem(name: "grant_type", value: "refresh_token"), URLQueryItem(name: "refresh_token", value: refresh)]
            let body = Data((form.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B").utf8)
            if let reply = try? await http.send(url: URL(string: "https://oauth2.googleapis.com/token")!, headers: ["Content-Type": "application/x-www-form-urlencoded"], body: body), reply.1 == 200,
               let access = (try? DesktopUsageParser.object(reply.0))?["access_token"] as? String {
                let ttl = (try? DesktopUsageParser.object(reply.0)).flatMap { DesktopUsageParser.number($0["expires_in"]) } ?? 3600
                do { try cache.save(access: access, source: refresh, expiresIn: ttl) }
                catch { cacheWarning = "Usage is live, but the renewed access token could not be cached on disk." }
                token = access; outcome = await cloud(token, http: http)
            }
        }
        guard var result = outcome.snapshot else { throw UsageFailure.unavailable("Antigravity usage is unavailable. Open the app to refresh its sign-in, then try again. Google’s quota service may also be temporarily unavailable.") }
        if let cacheWarning { result.note = (result.note ?? "") + " " + cacheWarning }
        return result
    }
    private static func local() async -> DesktopUsageSnapshot? {
        let deadline = Date().addingTimeInterval(20)
        guard let process = try? await CommandRunner.shared.run(executable: URL(fileURLWithPath: "/bin/ps"), arguments: ["-U", String(getuid()), "-o", "pid=,command="], timeout: 3) else { return nil }
        for server in servers(process.stdout).prefix(3) {
            guard let result = try? await CommandRunner.shared.run(executable: URL(fileURLWithPath: "/usr/sbin/lsof"), arguments: ["-nP", "-a", "-p", String(server.pid), "-iTCP", "-sTCP:LISTEN", "-Fn"], timeout: 3) else { continue }
            let foundPorts = ports(result.stdout)
            // Only ports confirmed as listening on the selected process. Never probe arbitrary ports.
            for port in foundPorts.prefix(4) {
                for scheme in ["https", "http"] {
                    guard Date() < deadline, !Task.isCancelled else { return nil }
                    let http = DesktopUsageTransport(loopbackPort: port)
                    func call(_ method: String) async -> (Data, Int)? {
                        let body = try? JSONSerialization.data(withJSONObject: ["metadata": ["ideName": "antigravity", "extensionName": "antigravity", "ideVersion": "unknown", "locale": "en"]])
                        return try? await http.send(url: URL(string: "\(scheme)://127.0.0.1:\(port)/exa.language_server_pb.LanguageServerService/\(method)")!,
                            headers: ["Content-Type": "application/json", "Connect-Protocol-Version": "1", "x-codeium-csrf-token": server.csrf], body: body)
                    }
                    guard let summary = await call("RetrieveUserQuotaSummary") else { continue }
                    if summary.1 == 200, let metrics = DesktopUsageParser.antigravitySummary(summary.0) {
                        return .init(metrics: metrics, source: "Antigravity local service", note: "Gemini models share one pool; Claude and other models share another. Antigravity and Antigravity IDE use these same account quotas.")
                    }
                    // A responding service may be an older build without quota-summary support.
                    for method in ["GetUserStatus", "GetCommandModelConfigs"] {
                        if let reply = await call(method), reply.1 == 200 {
                            let metrics = DesktopUsageParser.antigravityLegacy(reply.0)
                            if !metrics.isEmpty { return .init(metrics: metrics, source: "Antigravity local service", note: "This app version exposes 5-hour pools only. Weekly quotas weren’t reported.") }
                        }
                    }
                }
            }
        }
        return nil
    }
    private static func cloud(_ token: String, http: DesktopUsageTransport) async -> (snapshot: DesktopUsageSnapshot?, authFailed: Bool) {
        for base in ["https://daily-cloudcode-pa.googleapis.com", "https://cloudcode-pa.googleapis.com"] {
            for method in ["retrieveUserQuotaSummary", "fetchAvailableModels"] {
                guard let reply = try? await http.send(url: URL(string: "\(base)/v1internal:\(method)")!,
                    headers: ["Authorization": "Bearer \(token)", "Content-Type": "application/json", "User-Agent": "antigravity"], body: Data("{}".utf8)) else { continue }
                if reply.1 == 401 || reply.1 == 403 { return (nil, true) }
                guard reply.1 == 200 else { continue }
                if method == "retrieveUserQuotaSummary", let metrics = DesktopUsageParser.antigravitySummary(reply.0) {
                    return (.init(metrics: metrics, source: "Google Cloud Code · Antigravity sign-in", note: "Shared account pools for Antigravity and Antigravity IDE."), false)
                }
                let metrics = DesktopUsageParser.antigravityLegacy(reply.0)
                if !metrics.isEmpty { return (.init(metrics: metrics, source: "Google Cloud Code · Antigravity sign-in", note: "5-hour pools only. Weekly quotas weren’t reported by this endpoint."), false) }
            }
        }
        return (nil, false)
    }
}

// Live adapters use provider-owned read endpoints only. No inference requests are sent.
enum AdditionalUsageClient {
    static let providers: [UsageProvider] = [.anthropic, .google, .openai, .groq, .xai, .mistral, .zai, .minimax]
    static func requirements(_ provider: UsageProvider) -> String {
        switch provider {
        case .groq: return "Sign in to Groq Console to read this month’s organization requests, reported tokens, and costs. A standard Groq API key cannot read this data."
        case .anthropic: return "Connect your existing Claude Code sign-in to read session and weekly subscription limits."
        case .openai: return "Requires an OpenAI organization Admin API key. Reports this month’s organization costs; prepaid balance is not exposed by this endpoint."
        case .google: return "Requires a Google Cloud project ID and OAuth access token with Monitoring Viewer access. Reports Gemini output tokens over the last 24 hours; API keys alone cannot read account usage or credits."
        case .xai: return "Requires an xAI management API key and team ID. Reports team prepaid credits, separate from Grok subscriptions."
        case .mistral: return "Requires a Mistral Admin API key. Reads the organization’s current spending-limit status. Detailed cost totals are not yet supported."
        case .zai: return "Requires a Z.ai GLM Coding Plan API key. Reports subscription quota windows and monthly web-search calls."
        case .minimax: return "Requires a MiniMax Token Plan key. Reports remaining plan quotas; a pay-as-you-go API key does not provide subscription allowances."
        default: return "No verified account-usage endpoint is available."
        }
    }
    static func read(_ url: URL, key: String, headers: [String: String] = [:]) async throws -> [String: Any] {
        var headers = headers
        headers["Authorization"] = "Bearer \(key)"
        headers["Accept"] = "application/json"
        let (data, status) = try await DesktopUsageTransport().send(url: url, headers: headers, body: nil)
        guard status == 200 else {
            if status == 401 || status == 403 { throw UsageFailure.unavailable("Access denied. Check the credential type and permissions, then reconnect.") }
            if status == 429 { throw UsageFailure.unavailable("Provider rate limit reached. Wait for the next refresh.") }
            throw UsageFailure.unavailable("The provider returned HTTP \(status). Try again later.")
        }
        return try DesktopUsageParser.object(data)
    }
    static func fetch(_ provider: UsageProvider, key: String, scope: String = "") async throws -> DesktopUsageSnapshot {
        switch provider {
        case .groq:
            guard validScope(scope), scope.hasPrefix("org_") else { throw UsageFailure.unavailable("Reconnect to select your Groq organization.") }
            var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let start = calendar.dateInterval(of: .month, for: Date())!.start
            var url = URLComponents(string: "https://api.groq.com/platform/v1/organizations/\(scope)/activity")!
            url.queryItems = [.init(name: "start_date", value: String(Int(start.timeIntervalSince1970))), .init(name: "end_date", value: String(Int(Date().timeIntervalSince1970)))]
            let root = try await read(url.url!, key: key, headers: ["groq-organization": scope])
            return try parseGroq(root, organization: scope)
        case .anthropic:
            return try parseClaude(await read(URL(string: "https://api.anthropic.com/api/oauth/usage")!, key: key,
                headers: ["anthropic-beta": "oauth-2025-04-20", "User-Agent": "claude-code/2.1.69"]))
        case .zai:
            return try parseZAI(await read(URL(string: "https://api.z.ai/api/monitor/usage/quota/limit")!, key: key))
        case .minimax:
            return try parseMiniMax(await read(URL(string: "https://www.minimax.io/v1/token_plan/remains")!, key: key))
        case .openai:
            var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let start = calendar.dateInterval(of: .month, for: Date())!.start
            var amounts: [String: Double] = [:], page: String?, seen = Set<String>()
            for _ in 0..<100 {
                var url = URLComponents(string: "https://api.openai.com/v1/organization/costs")!
                url.queryItems = [.init(name: "start_time", value: String(Int(start.timeIntervalSince1970))), .init(name: "bucket_width", value: "1d"), .init(name: "limit", value: "31")]
                if let page { url.queryItems!.append(.init(name: "page", value: page)) }
                let root = try await read(url.url!, key: key)
                for (currency, value) in try costAmounts(root) { amounts[currency, default: 0] += value }
                if root["has_more"] as? Bool != true {
                    return .init(metrics: amounts.keys.sorted().map { .init(id: $0, title: "Organization cost · this month (UTC)", used: amounts[$0]!, limit: nil, unit: .currency($0), resetsAt: nil) }, source: "OpenAI organization Costs API", note: "Billed cost, not remaining credits. Provider reporting may be delayed.")
                }
                guard let next = root["next_page"] as? String, !next.isEmpty, seen.insert(next).inserted else { throw invalid() }; page = next
            }
            throw UsageFailure.unavailable("The cost report exceeded the pagination limit. No partial total is shown.")
        case .xai:
            guard validScope(scope) else { throw UsageFailure.unavailable("Enter your xAI team ID.") }
            let root = try await read(URL(string: "https://management-api.x.ai/v1/billing/teams/\(scope)/prepaid/balance")!, key: key)
            guard let total = root["total"] as? [String: Any], let raw = total["val"] as? String, let cents = Double(raw), cents.isFinite else { throw invalid() }
            // xAI represents purchased credit as a negative ledger balance, in USD cents.
            return .init(metrics: [.init(id: "credits", title: "Team prepaid credits", used: -cents / 100, limit: nil, unit: .dollars, resetsAt: nil, valueLabel: "available")], source: "xAI Management API", note: "Team \(scope). Credit ledger balance; excludes postpaid spending limits.")
        case .mistral:
            let root = try await read(URL(string: "https://api.mistral.ai/v1/admin/spend-limit")!, key: key, headers: ["x-api-key": key])
            guard let limits = root["limits"] as? [String: Any], let completion = limits["completion"] as? [String: Any], let reached = completion["monthly_limit_reached"] as? Bool else { throw invalid() }
            return .init(metrics: [], source: "Mistral Admin API", note: reached ? "Monthly spending limit reached. Cost and remaining-credit totals are not provided by this adapter yet." : "Monthly spending limit has not been reached. Cost and remaining-credit totals are not provided by this adapter yet.")
        case .google:
            guard validScope(scope) else { throw UsageFailure.unavailable("Enter your Google Cloud project ID.") }
            let end = Date(), start = end.addingTimeInterval(-86400), iso = ISO8601DateFormatter()
            var page: String?, totals: [String: Double] = [:], seen = Set<String>()
            for _ in 0..<100 {
                var url = URLComponents(string: "https://monitoring.googleapis.com/v3/projects/\(scope)/timeSeries")!
                url.queryItems = [.init(name: "filter", value: "metric.type=\"generativelanguage.googleapis.com/generate_content_usage_output_token_count\""), .init(name: "interval.startTime", value: iso.string(from: start)), .init(name: "interval.endTime", value: iso.string(from: end)), .init(name: "view", value: "FULL"), .init(name: "pageSize", value: "1000")]
                if let page { url.queryItems!.append(.init(name: "pageToken", value: page)) }
                let root = try await read(url.url!, key: key)
                for (model, value) in try googleAmounts(root) { totals[model, default: 0] += value }
                guard let next = root["nextPageToken"] as? String, !next.isEmpty else {
                    return .init(metrics: totals.keys.sorted().map { .init(id: $0, title: "\($0) · output tokens / 24h", used: totals[$0]!, limit: nil, unit: .requests, resetsAt: nil) }, source: "Google Cloud Monitoring · \(scope)", note: "Output tokens only, including reported modalities. No account balance or remaining quota is inferred. Empty series means no reported data.")
                }
                guard seen.insert(next).inserted else { throw invalid() }; page = next
            }
            throw UsageFailure.unavailable("Monitoring returned too many pages. No partial total is shown.")
        default: throw invalid()
        }
    }
    static func validScope(_ scope: String) -> Bool { !scope.isEmpty && scope.count < 200 && scope.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") } }
    static func invalid() -> UsageFailure { .unavailable("The provider returned no recognized usage data. Missing values are not treated as zero.") }
    // Verified against the Groq Console activity schema (2026-09-21). Free-plan costs
    // are projections, not charges. Missing optional fields are never filled with zero.
    static func parseGroq(_ root: [String: Any], organization: String) throws -> DesktopUsageSnapshot {
        guard root["object"] as? String == "list", let rows = root["data"] as? [[String: Any]],
              root["has_more"] as? Bool != true, root["next_page"] == nil || root["next_page"] is NSNull else { throw invalid() }
        var requests = 0.0, input = 0.0, output = 0.0, inputRows = 0, outputRows = 0
        var costs: [String: Double] = [:], missingCosts = false
        for row in rows {
            guard row["organization_id"] as? String == organization,
                  let count = DesktopUsageParser.number(row["num_requests"]),
                  let plan = row["plan_id"] as? String else { throw invalid() }
            requests += count
            if let value = DesktopUsageParser.number(row["n_context_tokens_total"]) { input += value; inputRows += 1 }
            if let value = DesktopUsageParser.number(row["n_generated_tokens_total"]) { output += value; outputRows += 1 }
            // Keep every plan separate, including historical plans from a mid-month upgrade.
            if let cost = DesktopUsageParser.number(row["cost"]) { costs[plan, default: 0] += cost }
            else { missingCosts = true }
        }
        var metrics: [DesktopUsageMetric] = []
        if !rows.isEmpty {
            metrics.append(.init(id: "requests", title: "Requests · this month (UTC)", used: requests, limit: nil, unit: .requests))
            if inputRows > 0 { metrics.append(.init(id: "input", title: "Reported input tokens", used: input, limit: nil, unit: .requests)) }
            if outputRows > 0 { metrics.append(.init(id: "output", title: "Reported output tokens", used: output, limit: nil, unit: .requests)) }
            if !missingCosts {
                for plan in costs.keys.sorted() {
                    let paid = ["developer", "growth", "enterprise"].contains { plan.hasPrefix($0) }
                    metrics.append(.init(id: "cost-" + plan, title: paid ? "Reported cost · \(plan)" : "Projected cost · \(plan.isEmpty ? "Free" : plan)", used: costs[plan]!, limit: nil, unit: .dollars, valueLabel: paid ? "reported" : "estimate"))
                }
            }
        }
        var note = "All projects in organization \(organization), current UTC month. Data can lag by 15 minutes. Free-plan costs are projections, not bills. This endpoint does not report account credits or remaining quota."
        if rows.isEmpty { note = "Groq reports no activity for this organization this month. " + note }
        if missingCosts { note += " Cost totals are unavailable because some rows omitted cost." }
        return .init(metrics: metrics, source: "Groq Console · organization activity", note: note)
    }

    static func parseClaude(_ root: [String: Any]) throws -> DesktopUsageSnapshot {
        var metrics: [DesktopUsageMetric] = []
        for (id, title) in [("five_hour", "Session · 5 hours"), ("seven_day", "Weekly"), ("seven_day_sonnet", "Sonnet · weekly"), ("seven_day_opus", "Opus · weekly")] {
            guard let item = root[id] as? [String: Any], let used = DesktopUsageParser.number(item["utilization"]) else { continue }
            metrics.append(.init(id: id, title: title, used: used, limit: 100, unit: .percent, resetsAt: DesktopUsageParser.date(item["resets_at"])))
        }
        if let extra = root["extra_usage"] as? [String: Any], extra["is_enabled"] as? Bool == true, let used = DesktopUsageParser.number(extra["used_credits"]) {
            metrics.append(.init(id: "extra", title: "Extra usage", used: used / 100, limit: DesktopUsageParser.number(extra["monthly_limit"]).map { $0 / 100 }, unit: .dollars, resetsAt: nil))
        }
        guard !metrics.isEmpty else { throw invalid() }
        return .init(metrics: metrics, source: "Claude subscription usage API", note: "Uses your Claude Code login. Open Claude Code to renew an expired sign-in; this app does not rotate its refresh token.")
    }
    static func parseZAI(_ root: [String: Any]) throws -> DesktopUsageSnapshot {
        guard root["success"] as? Bool != false, let limits = (root["data"] as? [String: Any] ?? root)["limits"] as? [[String: Any]] else { throw invalid() }
        var metrics: [DesktopUsageMetric] = []
        for (index, item) in limits.enumerated() {
            let type = item["type"] as? String ?? item["name"] as? String ?? ""
            let reset = DesktopUsageParser.number(item["nextResetTime"]).map { Date(timeIntervalSince1970: $0 / 1000) }
            if type == "CREDIT_LIMIT" || type == "TOKENS_LIMIT", let used = DesktopUsageParser.number(item["percentage"]), let unit = DesktopUsageParser.number(item["unit"]), let count = DesktopUsageParser.number(item["number"]), count > 0 {
                let suffix: String
                switch unit { case 3: suffix = "hours"; case 4: suffix = "days"; case 5: suffix = "months"; case 6: suffix = "weeks"; default: continue }
                metrics.append(.init(id: "window-\(index)", title: "Coding quota · \(Int(count)) \(suffix)", used: used, limit: 100, unit: .percent, resetsAt: reset))
            } else if type == "TIME_LIMIT", let used = DesktopUsageParser.number(item["currentValue"]), let limit = DesktopUsageParser.number(item["usage"]) {
                metrics.append(.init(id: "web-\(index)", title: "Web searches · monthly", used: used, limit: limit, unit: .requests, resetsAt: reset))
            }
        }
        if !limits.isEmpty && metrics.isEmpty { throw invalid() }
        return .init(metrics: metrics, source: "Z.ai Coding Plan quota API", note: "Subscription allowances, separate from pay-as-you-go API credits.")
    }
    static func parseMiniMax(_ root: [String: Any]) throws -> DesktopUsageSnapshot {
        let data = root["data"] as? [String: Any] ?? root
        if let status = (data["base_resp"] as? [String: Any] ?? root["base_resp"] as? [String: Any])?["status_code"], DesktopUsageParser.number(status) != 0 { throw invalid() }
        guard let models = data["model_remains"] as? [[String: Any]] else { throw invalid() }
        var metrics: [DesktopUsageMetric] = []
        for (index, model) in models.enumerated() {
            let name = model["model_name"] as? String ?? "Plan quota"
            for (prefix, title, end) in [("current_interval", "Current window", "end_time"), ("current_weekly", "Weekly", "weekly_end_time")] {
                let reset = DesktopUsageParser.number(model[end]).map { Date(timeIntervalSince1970: $0 > 1e12 ? $0 / 1000 : $0) }
                if let remaining = DesktopUsageParser.number(model[prefix + "_remaining_percent"]) {
                    metrics.append(.init(id: "\(index)-\(prefix)", title: "\(name) · \(title)", used: max(0, 100 - remaining), limit: 100, unit: .percent, resetsAt: reset))
                } else if let total = DesktopUsageParser.number(model[prefix + "_total_count"]), total > 0, let remaining = DesktopUsageParser.number(model[prefix + "_usage_count"]) {
                    // The remains endpoint's usage_count is remaining, despite the field name.
                    metrics.append(.init(id: "\(index)-\(prefix)", title: "\(name) · \(title)", used: max(0, total - remaining), limit: total, unit: .requests, resetsAt: reset))
                }
            }
        }
        guard !metrics.isEmpty else { throw invalid() }
        return .init(metrics: metrics, source: "MiniMax Token Plan remains API", note: "Each model/window is shown separately; shared pools are not summed. Pay-as-you-go balance is not included.")
    }
    static func costAmounts(_ root: [String: Any]) throws -> [String: Double] {
        guard let buckets = root["data"] as? [[String: Any]] else { throw invalid() }
        var amounts: [String: Double] = [:]
        for bucket in buckets {
            guard let results = bucket["results"] as? [[String: Any]] else { throw invalid() }
            for result in results {
                guard let amount = result["amount"] as? [String: Any], let value = DesktopUsageParser.number(amount["value"]), let currency = amount["currency"] as? String else { throw invalid() }
                amounts[currency.uppercased(), default: 0] += value
            }
        }
        return amounts
    }
    static func googleAmounts(_ root: [String: Any]) throws -> [String: Double] {
        guard root["error"] == nil else { throw invalid() }
        guard let series = root["timeSeries"] as? [[String: Any]] else {
            if root["timeSeries"] == nil { return [:] }; throw invalid()
        }
        var totals: [String: Double] = [:]
        for item in series {
            let model = ((item["metric"] as? [String: Any])?["labels"] as? [String: Any])?["model"] as? String ?? "All models"
            guard item["metricKind"] as? String == "DELTA", let points = item["points"] as? [[String: Any]] else { throw invalid() }
            for point in points {
                guard let value = point["value"] as? [String: Any], let count = DesktopUsageParser.number(value["int64Value"]) else { throw invalid() }
                totals[model, default: 0] += count
            }
        }
        return totals
    }
}

/// An expiring, source-bound access-token cache, matching OpenUsage's Antigravity strategy.
/// Only derived access tokens are persisted; source refresh credentials remain in Keychain.
struct AntigravityTokenCache {
    struct Entry: Codable {
        let accessToken: String
        let expiresAt: Date
        let sourceFingerprint: String
        func usable(source: String, now: Date) -> Bool {
            !accessToken.isEmpty && expiresAt.timeIntervalSince(now) > 60 && sourceFingerprint == AntigravityTokenCache.fingerprint(source)
        }
    }
    let directory: URL
    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("HarnessManager/usage/antigravity")) { self.directory = directory }
    static func fingerprint(_ source: String) -> String { SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined() }
    func load(source: String, now: Date = Date()) -> String? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("access.json")),
              let entry = try? JSONDecoder().decode(Entry.self, from: data), entry.usable(source: source, now: now) else { return nil }
        return entry.accessToken
    }
    func save(access: String, source: String, expiresIn: Double, now: Date = Date()) throws {
        guard expiresIn.isFinite, expiresIn > 60, !access.isEmpty, !source.isEmpty else { return }
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let data = try JSONEncoder().encode(Entry(accessToken: access, expiresAt: now.addingTimeInterval(expiresIn), sourceFingerprint: Self.fingerprint(source)))
        // Write into a private directory, then atomically replace with an owner-only file.
        let staging = directory.appendingPathComponent(UUID().uuidString)
        guard fm.createFile(atPath: staging.path, contents: data, attributes: [.posixPermissions: 0o600]) else { throw CocoaError(.fileWriteUnknown) }
        defer { try? fm.removeItem(at: staging) }
        let target = directory.appendingPathComponent("access.json")
        if fm.fileExists(atPath: target.path) { _ = try fm.replaceItemAt(target, withItemAt: staging) }
        else { try fm.moveItem(at: staging, to: target) }
    }
}
