import Darwin
import Foundation
import Observation
import Security
import LocalAuthentication
import WebKit

struct UsageWindow: Identifiable, Sendable {
    let id: String
    let name: String
    let usedPercent: Double
    let minutes: Int?
    let resetsAt: Date?
    var remaining: Double { max(0, 100 - usedPercent) }
    var duration: String {
        guard let minutes else { return "Usage window" }
        if minutes % 1440 == 0 { return "\(minutes / 1440)-day window" }
        if minutes % 60 == 0 { return "\(minutes / 60)-hour window" }
        return "\(minutes)-minute window"
    }
}

struct CodexUsage: Sendable {
    var windows: [UsageWindow]
    var lifetimeTokens: Int64?
    var tokenMessage: String?
    var fetchedAt = Date()
}

struct RouterUsage: Decodable, Sendable {
    let usage: Double?
    let usageDaily: Double?
    let usageMonthly: Double?
    let limit: Double?
    let limitRemaining: Double?
    let limitReset: String?
    enum CodingKeys: String, CodingKey {
        case usage, limit
        case usageDaily = "usage_daily", usageMonthly = "usage_monthly"
        case limitRemaining = "limit_remaining", limitReset = "limit_reset"
    }
}

struct RouterCredits: Decodable, Sendable {
    let totalCredits: Double
    let totalUsage: Double
    var balance: Double { totalCredits - totalUsage }
    enum CodingKeys: String, CodingKey { case totalCredits = "total_credits", totalUsage = "total_usage" }
}

enum UsageProvider: String, CaseIterable, Identifiable {
    case codex, cursor, antigravity, openrouter, anthropic, google, openai, groq, xai, mistral, zai, minimax
    var id: String { rawValue }
    var live: Bool { true }
    var name: String {
        switch self {
        case .codex: "Codex"
        case .cursor: "Cursor"
        case .antigravity: "Antigravity / IDE"
        case .openrouter: "OpenRouter"
        case .anthropic: "Claude"
        case .google: "Google Gemini API"
        case .openai: "OpenAI API"
        case .groq: "Groq"
        case .xai: "xAI"
        case .mistral: "Mistral"
        case .zai: "Z.ai"
        case .minimax: "MiniMax"
        }
    }
    var logo: String? {
        switch self {
        case .codex, .openai: "Logo-codex"
        case .cursor: "Logo-cursor"
        case .antigravity: "Logo-antigravity"
        case .anthropic: "Logo-claude-code"
        case .google: "Logo-gemini-cli"
        default: nil
        }
    }
}

@Observable @MainActor final class UsagePreferences {
    private let defaults: UserDefaults
    private(set) var choices: [String: Bool]
    private(set) var initialized: Bool
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        choices = defaults.dictionary(forKey: "usage.providerChoices") as? [String: Bool] ?? [:]
        initialized = defaults.bool(forKey: "usage.providerDefaultsInitialized")
        // The old format saved a complete selection once any toggle was changed.
        // Preserve it on upgrade rather than guessing which enabled accounts were intentional.
        if !initialized, let disabled = defaults.stringArray(forKey: "usage.disabledProviders") {
            choices = Dictionary(uniqueKeysWithValues: UsageProvider.allCases.map { ($0.rawValue, !disabled.contains($0.rawValue)) })
            initialized = true
            persist()
        }
    }
    func enabled(_ provider: UsageProvider) -> Bool { choices[provider.rawValue] ?? false }
    func initializeDetected(_ detected: Set<UsageProvider>) {
        guard !initialized else { return }
        for provider in UsageProvider.allCases where choices[provider.rawValue] == nil {
            choices[provider.rawValue] = detected.contains(provider)
        }
        initialized = true
        persist()
    }
    func set(_ provider: UsageProvider, enabled: Bool) {
        choices[provider.rawValue] = enabled
        persist()
    }
    private func persist() {
        defaults.set(choices, forKey: "usage.providerChoices")
        defaults.set(initialized, forKey: "usage.providerDefaultsInitialized")
    }
}

enum UsageFailure: LocalizedError {
    case unavailable(String)
    var errorDescription: String? { if case .unavailable(let message) = self { return message }; return nil }
}

enum UsageParser {
    static func codex(_ data: Data) throws -> [UsageWindow] {
        struct Window: Decodable { let usedPercent: Double?; let windowDurationMins: Int?; let resetsAt: Double? }
        struct Bucket: Decodable { let limitName: String?; let primary: Window?; let secondary: Window? }
        struct Reply: Decodable { let rateLimits: Bucket?; let rateLimitsByLimitId: [String: Bucket]? }
        let reply = try JSONDecoder().decode(Reply.self, from: data)
        let buckets = reply.rateLimitsByLimitId.flatMap { $0.isEmpty ? nil : $0 }
            ?? reply.rateLimits.map { ["codex": $0] } ?? [:]
        return buckets.sorted { $0.key < $1.key }.flatMap { id, bucket in
            [("primary", bucket.primary), ("secondary", bucket.secondary)].compactMap { slot, window in
                guard let window, let used = window.usedPercent, used.isFinite, used >= 0 else { return nil }
                return UsageWindow(id: "\(id)-\(slot)", name: bucket.limitName ?? (id == "codex" ? "Codex" : id),
                    usedPercent: min(100, used), minutes: window.windowDurationMins,
                    resetsAt: window.resetsAt.map { Date(timeIntervalSince1970: $0) })
            }
        }
    }

    static func tokens(_ data: Data) throws -> Int64? {
        struct Summary: Decodable { let lifetimeTokens: Int64? }
        struct Reply: Decodable { let summary: Summary? }
        return try JSONDecoder().decode(Reply.self, from: data).summary?.lifetimeTokens
    }

    static func router(_ data: Data) throws -> RouterUsage {
        struct Reply: Decodable { let data: RouterUsage }
        return try JSONDecoder().decode(Reply.self, from: data).data
    }
    static func credits(_ data: Data) throws -> RouterCredits {
        struct Reply: Decodable { let data: RouterCredits }
        let value = try JSONDecoder().decode(Reply.self, from: data).data
        guard value.totalCredits.isFinite, value.totalUsage.isFinite, value.totalCredits >= 0, value.totalUsage >= 0 else {
            throw UsageFailure.unavailable("OpenRouter returned invalid account credit totals.")
        }
        return value
    }
}

/// A short-lived, read-only client of the official Codex CLI. Never starts a thread or turn.
enum CodexUsageClient {
    static func fetch() async throws -> CodexUsage {
        let path = await PathEnvironmentService.shared.fastPATH()
        let bundled = ["/Applications/Codex.app/Contents/Resources/codex", "/Applications/ChatGPT.app/Contents/Resources/codex"]
        guard let executable = CommandRunner.resolveExecutable(named: "codex", pathEnvironment: path)
            ?? bundled.first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map({ URL(fileURLWithPath: $0) }) else {
            throw UsageFailure.unavailable("Install Codex and sign in with your ChatGPT account to see subscription usage.")
        }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do { continuation.resume(returning: try read(executable: executable, path: path)) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    private static func read(executable: URL, path: String) throws -> CodexUsage {
        let process = Process(), input = Pipe(), output = Pipe()
        let inbox = UsageRPCInbox()
        process.executableURL = executable
        process.arguments = ["app-server"]
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = path
        process.environment = environment
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        output.fileHandleForReading.readabilityHandler = { handle in inbox.append(handle.availableData) }
        defer {
            output.fileHandleForReading.readabilityHandler = nil
            try? input.fileHandleForWriting.close()
            if process.isRunning {
                process.terminate()
                let end = Date().addingTimeInterval(0.5)
                while process.isRunning && Date() < end { Thread.sleep(forTimeInterval: 0.02) }
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            }
        }
        do { try process.run() }
        catch { throw UsageFailure.unavailable("Codex could not start. Open Codex, confirm you are signed in, then refresh.") }
        func send(_ object: [String: Any]) throws {
            var data = try JSONSerialization.data(withJSONObject: object)
            data.append(10)
            try input.fileHandleForWriting.write(contentsOf: data)
        }
        func request(_ id: Int, _ method: String, params: [String: Any] = [:]) throws -> Data {
            try send(["id": id, "method": method, "params": params])
            return try inbox.response(id: id, timeout: 12)
        }
        _ = try request(1, "initialize", params: ["clientInfo": ["name": "harness_manager", "title": "Harness Manager", "version": "1.0"]])
        try send(["method": "initialized", "params": [:]])
        let windows = try UsageParser.codex(request(2, "account/rateLimits/read"))
        var result = CodexUsage(windows: windows)
        do { result.lifetimeTokens = try UsageParser.tokens(request(3, "account/usage/read")) }
        catch { result.tokenMessage = "Token totals aren’t available from this Codex version or account." }
        return result
    }
}

private final class UsageRPCInbox: @unchecked Sendable {
    private let condition = NSCondition()
    private var buffer = Data()
    private var replies: [Int: Data] = [:]
    private var ended = false

    func append(_ data: Data) {
        condition.lock(); defer { condition.broadcast(); condition.unlock() }
        if data.isEmpty { ended = true; return }
        buffer.append(data)
        if buffer.count > 2_000_000 { buffer.removeAll(); ended = true; return }
        while let newline = buffer.firstIndex(of: 10) {
            let line = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)
            if let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any], let id = object["id"] as? Int, (1...3).contains(id) {
                replies[id] = line
            }
        }
    }

    func response(id: Int, timeout: TimeInterval) throws -> Data {
        condition.lock(); defer { condition.unlock() }
        let deadline = Date().addingTimeInterval(timeout)
        while replies[id] == nil && !ended {
            if !condition.wait(until: deadline) { break }
        }
        guard let data = replies.removeValue(forKey: id),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageFailure.unavailable("Codex didn’t respond in time. Open Codex and try refreshing.")
        }
        guard object["error"] == nil, let result = object["result"] as? [String: Any] else {
            throw UsageFailure.unavailable("Usage isn’t available for this Codex session. Sign in to Codex with ChatGPT and refresh. API-key accounts don’t provide subscription limits.")
        }
        return try JSONSerialization.data(withJSONObject: result)
    }
}

/// Security.framework can wait indefinitely for a locked or inaccessible login keychain.
/// Bound the caller's wait and allow only one pending OS read per credential source.
enum UsageCredentialReader {
    private static let gate = CredentialReadGate()
    static func read<T: Sendable>(_ id: String, timeout: TimeInterval = 4, operation: @escaping @Sendable () throws -> T) async throws -> T {
        guard gate.begin(id) else { throw UsageFailure.unavailable("macOS Keychain access is still waiting. Unlock Keychain or reconnect this provider’s saved sign-in.") }
        return try await withCheckedThrowingContinuation { continuation in
            let completion = CredentialReadCompletion(continuation)
            DispatchQueue.global(qos: .utility).async {
                defer { gate.end(id) }
                do { completion.finish(.success(try operation())) }
                catch { completion.finish(.failure(error)) }
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                completion.finish(.failure(UsageFailure.unavailable("macOS Keychain didn’t respond. Unlock Keychain or reconnect this provider’s saved sign-in, then refresh.")))
            }
        }
    }
}

private final class CredentialReadGate: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = Set<String>()
    func begin(_ id: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return pending.insert(id).inserted
    }
    func end(_ id: String) { lock.lock(); pending.remove(id); lock.unlock() }
}

private final class CredentialReadCompletion<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?
    init(_ continuation: CheckedContinuation<T, Error>) { self.continuation = continuation }
    func finish(_ result: Result<T, Error>) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}

/// Session-only credential cache. Failures are cached too: polling never retries authorization.
actor UsageCredentialSession {
    static let shared = UsageCredentialSession()
    private var reads: [String: Task<String?, Error>] = [:]
    func read(_ id: String, loader: @escaping @Sendable () async throws -> String?) async throws -> String? {
        if let task = reads[id] { return try await task.value }
        let task = Task { try await loader() }
        reads[id] = task
        return try await task.value
    }
    func set(_ id: String, value: String?) { reads[id] = Task { value } }
}

/// LAContext's no-UI flag does not reliably cover the legacy login keychain.
/// Serialize our Security calls and suppress legacy interaction as well as modern auth UI.
/// This only prevents prompts; denied reads still fail and no access controls are changed.
enum UsageKeychainInteraction {
    private static let lock = NSLock()
    static func run<T>(allowUI: Bool = false, _ operation: () throws -> T) throws -> T {
        lock.lock(); defer { lock.unlock() }
        var previous: DarwinBoolean = false
        guard SecKeychainGetUserInteractionAllowed(&previous) == errSecSuccess,
              SecKeychainSetUserInteractionAllowed(allowUI) == errSecSuccess else {
            throw UsageFailure.unavailable("Keychain access needs attention. Reconnect this provider from Usage.")
        }
        defer { SecKeychainSetUserInteractionAllowed(previous.boolValue) }
        return try operation()
    }
    static func read(service: String, account: String?) throws -> String? {
        try run {
            var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service, kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne]
            if let account { query[kSecAttrAccount as String] = account }
            let context = LAContext()
            context.interactionNotAllowed = true
            query[kSecUseAuthenticationContext as String] = context
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            if status == errSecItemNotFound { return nil }
            guard status == errSecSuccess, let data = result as? Data else {
                throw UsageFailure.unavailable("Keychain access needs approval. Reconnect this provider from Usage; automatic refresh won’t ask for your password.")
            }
            return String(data: data, encoding: .utf8)
        }
    }
}

enum UsageKeychain {
    private static let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.harnessmanager.usage", kSecAttrAccount as String: "openrouter"]
    static func read(account: String = "openrouter") async throws -> String? {
        try await UsageCredentialSession.shared.read(account) {
            try await UsageCredentialReader.read(account) {
                try UsageKeychainInteraction.read(service: "com.harnessmanager.usage", account: account)
            }
        }
    }
    static func save(_ key: String, account: String = "openrouter") throws {
        try UsageKeychainInteraction.run(allowUI: true) {
        var query = Self.query
        query[kSecAttrAccount as String] = account
        let attributes = [kSecValueData as String: Data(key.utf8)]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query.merging(attributes) { _, new in new }
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw UsageFailure.unavailable("Couldn’t save the key in macOS Keychain. Please try again.") }
        }
    }
    static func remove(account: String = "openrouter") throws {
        try UsageKeychainInteraction.run(allowUI: true) {
        var query = Self.query
        query[kSecAttrAccount as String] = account
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw UsageFailure.unavailable("Couldn’t remove the key from macOS Keychain.") }
        }
    }
}

private final class RouterUsageHTTPDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@Observable @MainActor
final class UsageStore {
    static let shared = UsageStore()
    let preferences = UsagePreferences()
    private var tasks: [UsageProvider: Task<Void, Never>] = [:]
    var routerCredits: RouterCredits?
    var creditsFetchedAt: Date?
    var creditsError: String?
    var creditsConnected = false
    var creditsLoading = false
    var codex: CodexUsage?
    var router: RouterUsage?
    var routerFetchedAt: Date?
    var codexError: String?
    var routerError: String?
    var codexLoading = false
    var routerLoading = false
    var routerConnected = false
    var additionalSnapshots: [UsageProvider: DesktopUsageSnapshot] = [:]
    var additionalErrors: [UsageProvider: String] = [:]
    var additionalLoading: Set<UsageProvider> = []
    var cursor: DesktopUsageSnapshot?
    var antigravity: DesktopUsageSnapshot?
    var cursorError: String?
    var antigravityError: String?
    var cursorLoading = false
    var antigravityLoading = false
    private var lastAttempt: Date?
    var loading: Bool { codexLoading || routerLoading || cursorLoading || antigravityLoading || creditsLoading || !additionalLoading.isEmpty }

    func setEnabled(_ provider: UsageProvider, _ enabled: Bool) {
        preferences.set(provider, enabled: enabled)
        if !enabled { tasks[provider]?.cancel() }
        else if provider.live { lastAttempt = nil; Task { await refresh(force: true) } }
    }

    func refresh(force: Bool = false) async {
        guard force || lastAttempt == nil || Date().timeIntervalSince(lastAttempt!) >= 300 else { return }
        lastAttempt = Date()
        for provider in UsageProvider.allCases where provider.live && preferences.enabled(provider) && tasks[provider] == nil {
            if provider == .antigravity && antigravityLoading { continue }
            if additionalLoading.contains(provider) { continue }
            tasks[provider] = Task {
                switch provider {
                case .codex: await refreshCodex()
                case .cursor: await refreshCursor()
                case .antigravity: await refreshAntigravity()
                case .openrouter:
                    let credential = Task { try await UsageKeychain.read() }
                    async let key: Void = refreshRouter(credential: credential)
                    async let balance: Void = refreshCredits(credential: credential)
                    _ = await (key, balance)
                default: await refreshAdditional(provider)
                }
                tasks[provider] = nil
                if Task.isCancelled && preferences.enabled(provider) {
                    Task { await refresh(force: true) }
                }
            }
        }
        let pending = Array(tasks.values)
        for task in pending { await task.value }
    }

    private func refreshCursor() async {
        cursorLoading = true
        defer { cursorLoading = false }
        do { let result = try await CursorUsageClient.fetch(); guard !Task.isCancelled else { return }; cursor = result; cursorError = nil }
        catch {
            cursor = nil
            cursorError = (error as? UsageFailure)?.errorDescription ?? "Couldn’t reach Cursor. Check your connection and refresh."
        }
    }

    private func refreshAntigravity() async {
        antigravityLoading = true
        defer { antigravityLoading = false }
        do { let result = try await AntigravityUsageClient.fetch(); guard !Task.isCancelled else { return }; antigravity = result; antigravityError = nil }
        catch {
            antigravity = nil
            antigravityError = (error as? UsageFailure)?.errorDescription ?? "Couldn’t reach Antigravity. Open the app and refresh."
        }
    }

    func reconnectAntigravity() async {
        guard tasks[.antigravity] == nil, !antigravityLoading else { return }
        antigravityLoading = true
        do {
            try await DesktopUsageCredentials.authorizeAntigravity()
            await refreshAntigravity()
        } catch {
            antigravityError = (error as? UsageFailure)?.errorDescription ?? "Antigravity authorization was cancelled. Try Reconnect when ready."
        }
        antigravityLoading = false
    }

    private func refreshCodex() async {
        codexLoading = true
        defer { codexLoading = false }
        do { let result = try await CodexUsageClient.fetch(); guard !Task.isCancelled else { return }; codex = result; codexError = nil }
        catch { codexError = (error as? UsageFailure)?.errorDescription ?? "Couldn’t read Codex usage. Update Codex, then refresh." }
    }

    private func refreshRouter(credential: Task<String?, Error>? = nil) async {
        guard !Task.isCancelled else { return }
        routerLoading = true
        defer { routerLoading = false }
        do {
            let savedKey: String?
            if let credential { savedKey = try await credential.value }
            else { savedKey = try await UsageKeychain.read() }
            guard let key = savedKey, !key.isEmpty else { routerConnected = false; return }
            guard !Task.isCancelled else { return }
            routerConnected = true
            let result = try await Self.fetchRouter(key); guard !Task.isCancelled else { return }; router = result; routerFetchedAt = Date(); routerError = nil
        }
        catch { routerError = (error as? UsageFailure)?.errorDescription ?? "Couldn’t reach OpenRouter. Check your connection and refresh." }
    }

    private func refreshCredits(credential: Task<String?, Error>? = nil) async {
        guard !Task.isCancelled else { return }
        creditsLoading = true
        defer { creditsLoading = false }
        do {
            let dedicated = try await UsageKeychain.read(account: "openrouter-credits")
            creditsConnected = dedicated != nil
            var fallback: String?
            if dedicated == nil {
                if let credential { fallback = try await credential.value }
                else { fallback = try await UsageKeychain.read() }
            }
            guard let key = dedicated ?? fallback, !key.isEmpty, !Task.isCancelled else { return }
            let result = try UsageParser.credits(await Self.fetchRouterData(key, credits: true))
            guard !Task.isCancelled else { return }
            routerCredits = result; creditsFetchedAt = Date(); creditsError = nil
        } catch {
            creditsError = (error as? UsageFailure)?.errorDescription ?? "Account credits couldn’t be fetched. Try refreshing."
        }
    }

    func connectCredits(_ rawKey: String) async throws {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw UsageFailure.unavailable("Enter an OpenRouter management key.") }
        creditsLoading = true
        defer { creditsLoading = false }
        let result = try UsageParser.credits(await Self.fetchRouterData(key, credits: true))
        try await Task.detached(priority: .utility) { try UsageKeychain.save(key, account: "openrouter-credits") }.value
        await UsageCredentialSession.shared.set("openrouter-credits", value: key)
        routerCredits = result; creditsFetchedAt = Date(); creditsError = nil; creditsConnected = true
    }

    func disconnectCredits() async throws {
        try await Task.detached { try UsageKeychain.remove(account: "openrouter-credits") }.value
        await UsageCredentialSession.shared.set("openrouter-credits", value: nil)
        routerCredits = nil; creditsFetchedAt = nil; creditsError = nil; creditsConnected = false
    }

    func connectRouter(_ rawKey: String) async throws {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw UsageFailure.unavailable("Enter an OpenRouter API key.") }
        routerLoading = true
        defer { routerLoading = false }
        let result = try await Self.fetchRouter(key)
        try await Task.detached(priority: .utility) { try UsageKeychain.save(key) }.value
        await UsageCredentialSession.shared.set("openrouter", value: key)
        router = result; routerFetchedAt = Date(); routerConnected = true; routerError = nil
        routerCredits = nil; creditsFetchedAt = nil; creditsError = nil
        await refreshCredits()
    }

    func disconnectRouter() async throws {
        try await Task.detached { try UsageKeychain.remove() }.value
        await UsageCredentialSession.shared.set("openrouter", value: nil)
        router = nil; routerFetchedAt = nil; routerConnected = false; routerError = nil
        if !creditsConnected { routerCredits = nil; creditsFetchedAt = nil; creditsError = nil }
    }

    private static func fetchRouter(_ key: String) async throws -> RouterUsage {
        try UsageParser.router(await fetchRouterData(key, credits: false))
    }

    private static func fetchRouterData(_ key: String, credits: Bool) async throws -> Data {
        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/\(credits ? "credits" : "key")")!)
        request.timeoutInterval = 20
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        let session = URLSession(configuration: configuration, delegate: RouterUsageHTTPDelegate(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode
            if credits && code == 403 { throw UsageFailure.unavailable("Account balance requires an OpenRouter management key. Connect one here; your existing key budget stays connected separately.") }
            throw UsageFailure.unavailable(code == 401 || code == 403 ? "OpenRouter rejected this key. Check the key and reconnect." : "OpenRouter usage is temporarily unavailable. Try refreshing shortly.")
        }
        return data
    }
}

struct UsageConnectionCredential: Codable, Sendable {
    let key: String
    let scope: String
}

extension UsageStore {
    func refreshAdditional(_ provider: UsageProvider) async {
        additionalLoading.insert(provider)
        defer { additionalLoading.remove(provider) }
        do {
            let credential: UsageConnectionCredential
            if provider == .groq {
                guard GroqConsoleSession.shared.connected else { additionalErrors[provider] = nil; return }
                credential = try await GroqConsoleSession.shared.credential()
            } else if provider == .anthropic {
                guard let token = try await claudeCredential() else { throw UsageFailure.unavailable("Sign in to Claude Code, then choose Connect Claude Code.") }
                credential = .init(key: token, scope: "")
            } else {
                guard let raw = try await UsageKeychain.read(account: "usage-" + provider.id),
                      let saved = try? JSONDecoder().decode(UsageConnectionCredential.self, from: Data(raw.utf8)) else {
                    additionalErrors[provider] = nil; return
                }
                credential = saved
            }
            let snapshot = try await AdditionalUsageClient.fetch(provider, key: credential.key, scope: credential.scope)
            guard !Task.isCancelled else { return }
            additionalSnapshots[provider] = snapshot; additionalErrors[provider] = nil
        } catch {
            guard !Task.isCancelled else { return }
            additionalSnapshots[provider] = nil
            additionalErrors[provider] = (error as? UsageFailure)?.errorDescription ?? "Couldn’t fetch usage. Check your connection and try again."
        }
    }
    func connectAdditional(_ provider: UsageProvider, key: String, scope: String) async throws {
        guard !additionalLoading.contains(provider) else { throw UsageFailure.unavailable("Wait for the current usage check to finish, then connect.") }
        additionalLoading.insert(provider)
        defer { additionalLoading.remove(provider) }
        let credential = UsageConnectionCredential(key: key.trimmingCharacters(in: .whitespacesAndNewlines), scope: scope.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !credential.key.isEmpty else { throw UsageFailure.unavailable("Enter a credential with usage-reading permissions.") }
        let snapshot = try await AdditionalUsageClient.fetch(provider, key: credential.key, scope: credential.scope)
        let raw = String(decoding: try JSONEncoder().encode(credential), as: UTF8.self), account = "usage-" + provider.id
        try await Task.detached { try UsageKeychain.save(raw, account: account) }.value
        await UsageCredentialSession.shared.set(account, value: raw)
        additionalSnapshots[provider] = snapshot; additionalErrors[provider] = nil
    }
    func connectClaude() async {
        guard !additionalLoading.contains(.anthropic) else { return }
        additionalLoading.insert(.anthropic)
        defer { additionalLoading.remove(.anthropic) }
        do {
            let result = try await CommandRunner.shared.run(executable: URL(fileURLWithPath: "/usr/bin/security"), arguments: ["find-generic-password", "-s", "Claude Code-credentials", "-w"], timeout: 60)
            guard result.exitCode == 0, let token = Self.claudeToken(result.stdout) else { throw UsageFailure.unavailable("Sign in to Claude Code and approve its Keychain read, then try Connect again.") }
            await UsageCredentialSession.shared.set("claude-usage", value: token)
            let snapshot = try await AdditionalUsageClient.fetch(.anthropic, key: token)
            additionalSnapshots[.anthropic] = snapshot; additionalErrors[.anthropic] = nil
        } catch { additionalErrors[.anthropic] = (error as? UsageFailure)?.errorDescription ?? "Claude sign-in could not be read." }
    }
    private func claudeCredential() async throws -> String? {
        try await UsageCredentialSession.shared.read("claude-usage") {
            try await UsageCredentialReader.read("claude-usage") {
                if let raw = try UsageKeychainInteraction.read(service: "Claude Code-credentials", account: nil) { return Self.claudeToken(raw) }
                let folder = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"] ?? NSHomeDirectory() + "/.claude"
                guard let raw = try? String(contentsOfFile: folder + "/.credentials.json", encoding: .utf8) else { return nil }
                return Self.claudeToken(raw)
            }
        }
    }
    nonisolated static func claudeToken(_ raw: String) -> String? {
        guard let root = try? DesktopUsageParser.object(Data(raw.utf8)), let oauth = root["claudeAiOauth"] as? [String: Any], let token = oauth["accessToken"] as? String, !token.isEmpty else { return nil }
        return token
    }
}

/// Groq's console authenticates its platform API with Stytch's session JWT. Keep the
/// session in a dedicated WebKit store; never read cookies from the user's browser.
@MainActor final class GroqConsoleSession: NSObject, WKUIDelegate {
    static let shared = GroqConsoleSession()
    let webView: WKWebView
    var presenting = false
    private let defaults = UserDefaults.standard
    var connected: Bool { defaults.string(forKey: "usage.groq.organization") != nil }
    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore(forIdentifier: UUID(uuidString: "1794C455-E998-4CB5-83A6-3C09B941B107")!)
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.uiDelegate = self
    }
    func showLogin() {
        presenting = true
        webView.load(URLRequest(url: URL(string: "https://console.groq.com/dashboard/usage")!))
    }
    nonisolated static func parseSession(_ jwt: String, now: Date = Date()) -> UsageConnectionCredential? {
        guard let claims = DesktopUsageParser.jwt(jwt),
              let expires = DesktopUsageParser.number(claims["exp"]), expires > now.timeIntervalSince1970 + 60 else { return nil }
        let org = (claims["https://groq.com/organization"] as? [String: Any])?["id"] as? String
            ?? (claims["https://stytch.com/organization"] as? [String: Any])?["slug"] as? String
        guard let org, org.hasPrefix("org_"), AdditionalUsageClient.validScope(org) else { return nil }
        // Parsing is not authentication. The platform usage request verifies the credential.
        return .init(key: jwt, scope: org)
    }
    private func savedSession() async -> UsageConnectionCredential? {
        let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
        return cookies.filter { $0.name == "stytch_session_jwt" && ["console.groq.com", ".console.groq.com", ".groq.com", "groq.com"].contains($0.domain) }
            .compactMap { Self.parseSession($0.value) }.first
    }
    func credential(connecting: Bool = false) async throws -> UsageConnectionCredential {
        if presenting && !connecting { throw UsageFailure.unavailable("Finish the Groq connection window, then refresh.") }
        if let session = await savedSession() { return try checked(session, connecting: connecting) }
        if !connecting {
            // Let Groq's own SDK renew its existing session. No sign-in UI opens in the background.
            webView.load(URLRequest(url: URL(string: "https://console.groq.com/dashboard/usage")!))
        }
        for _ in 0..<20 {
            try Task.checkCancellation()
            try await Task.sleep(for: .seconds(1))
            if let session = await savedSession() { return try checked(session, connecting: connecting) }
        }
        throw UsageFailure.unavailable("Sign in to Groq Console in the connection window, then click Connect. If the session expired, sign in again; background refresh will not open a login window.")
    }
    private func checked(_ session: UsageConnectionCredential, connecting: Bool) throws -> UsageConnectionCredential {
        if !connecting, defaults.string(forKey: "usage.groq.organization") != session.scope {
            throw UsageFailure.unavailable("Groq’s signed-in organization changed. Reconnect to confirm the new account.")
        }
        return session
    }
    func remember(_ scope: String) { defaults.set(scope, forKey: "usage.groq.organization") }
    func disconnect() async {
        defaults.removeObject(forKey: "usage.groq.organization")
        webView.stopLoading()
        await webView.configuration.websiteDataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if presenting, navigationAction.request.url?.scheme == "https" { webView.load(navigationAction.request) }
        return nil
    }
}

extension UsageStore {
    func connectGroq() async throws {
        guard !additionalLoading.contains(.groq) else { throw UsageFailure.unavailable("Wait for the current Groq check to finish.") }
        additionalLoading.insert(.groq)
        defer { additionalLoading.remove(.groq) }
        let credential = try await GroqConsoleSession.shared.credential(connecting: true)
        let snapshot = try await AdditionalUsageClient.fetch(.groq, key: credential.key, scope: credential.scope)
        GroqConsoleSession.shared.remember(credential.scope)
        additionalSnapshots[.groq] = snapshot; additionalErrors[.groq] = nil
    }
    func disconnectGroq() async {
        tasks[.groq]?.cancel()
        await tasks[.groq]?.value
        await GroqConsoleSession.shared.disconnect()
        additionalSnapshots[.groq] = nil; additionalErrors[.groq] = nil
    }
}
