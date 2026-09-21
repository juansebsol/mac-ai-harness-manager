import Foundation
import Observation

enum DiscoverCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case harnesses = "Harnesses", mcps = "MCPs", skills = "Skills"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .harnesses: return "terminal"
        case .mcps: return "point.3.connected.trianglepath.dotted"
        case .skills: return "sparkles"
        }
    }
    var queries: [String] {
        switch self {
        case .harnesses: return ["topic:coding-agent", "topic:agentic-ide"]
        case .mcps: return ["mcp in:name topic:mcp-server"]
        case .skills: return ["topic:agent-skills", "topic:claude-skills"]
        }
    }
}

struct DiscoverRepository: Codable, Identifiable, Sendable {
    let repository: String
    var name: String
    var summary: String
    var kind: String
    var stars: Int?
    var archived = false
    var id: String { repository.lowercased() }
    var url: URL { URL(string: "https://github.com/\(repository)")! }
    var avatarURL: URL { URL(string: "https://github.com/\(repository.split(separator: "/")[0]).png?size=96")! }

    static func validRepository(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$"#, options: .regularExpression) != nil
    }

    static func sorted(_ items: [Self]) -> [Self] {
        items.sorted {
            if $0.archived != $1.archived { return !$0.archived }
            if $0.stars != $1.stars { return ($0.stars ?? -1) > ($1.stars ?? -1) }
            return $0.id < $1.id
        }
    }
}

enum DiscoverCatalogService {
    static let seeds: [DiscoverCategory: [DiscoverRepository]] = [
        .skills: [
            .init(repository: "multica-ai/andrej-karpathy-skills", name: "Karpathy Skills", summary: "Coding guidelines inspired by Karpathy’s observations. Community maintained by Multica.", kind: "Skill & guidelines"),
            .init(repository: "DietrichGebert/ponytail", name: "Ponytail", summary: "Guidance for simpler solutions and less unnecessary code.", kind: "Skill"),
            .init(repository: "nextlevelbuilder/ui-ux-pro-max-skill", name: "UI UX Pro Max", summary: "Design guidance and UI/UX resources for coding agents.", kind: "Skill toolkit"),
            .init(repository: "Graphify-Labs/graphify", name: "Graphify", summary: "Explore code and documentation through a queryable knowledge graph.", kind: "Tool & skill"),
            .init(repository: "JuliusBrussee/caveman", name: "Caveman", summary: "A concise communication style for coding agents.", kind: "Skill & tool"),
            .init(repository: "addyosmani/agent-skills", name: "Addy Osmani Skills", summary: "Engineering practices packaged as reusable agent skills.", kind: "Skill collection"),
            .init(repository: "Leonxlnx/taste-skill", name: "Taste Skill", summary: "Design direction for more considered frontend interfaces.", kind: "Skill collection"),
            .init(repository: "Egonex-AI/Understand-Anything", name: "Understand Anything", summary: "Explore a codebase using interactive knowledge graphs.", kind: "Tool & skills"),
            .init(repository: "ComposioHQ/awesome-claude-skills", name: "Awesome Claude Skills", summary: "A directory of skills, resources, and workflow tools.", kind: "Collection & directory"),
            .init(repository: "tt-a1i/archify", name: "Archify", summary: "Create architecture and workflow diagrams with exportable HTML.", kind: "Skill")
        ],
        .mcps: [
            .init(repository: "modelcontextprotocol/servers", name: "MCP Reference Servers", summary: "Reference implementations and links to MCP servers.", kind: "Server collection"),
            .init(repository: "github/github-mcp-server", name: "GitHub MCP", summary: "Connect agents to GitHub repositories, issues, and pull requests.", kind: "MCP server"),
            .init(repository: "microsoft/playwright-mcp", name: "Playwright MCP", summary: "Browser automation through the Model Context Protocol.", kind: "MCP server"),
            .init(repository: "upstash/context7", name: "Context7", summary: "Library documentation and code examples for coding agents.", kind: "MCP server"),
            .init(repository: "ChromeDevTools/chrome-devtools-mcp", name: "Chrome DevTools MCP", summary: "Inspect and debug browser sessions from your agent.", kind: "MCP server")
        ],
        .harnesses: [
            .init(repository: "anthropics/claude-code", name: "Claude Code", summary: "Anthropic’s coding agent.", kind: "Coding harness"),
            .init(repository: "openai/codex", name: "Codex", summary: "OpenAI’s coding agent.", kind: "Coding harness"),
            .init(repository: "google-gemini/gemini-cli", name: "Gemini CLI", summary: "Gemini in your terminal.", kind: "Coding harness"),
            .init(repository: "stablyai/orca", name: "Orca", summary: "Parallel coding-agent workspaces.", kind: "Meta harness"),
            .init(repository: "pingdotgg/t3code", name: "T3 Code", summary: "A control plane for coding agents.", kind: "Meta harness"),
            .init(repository: "getpaseo/paseo", name: "Paseo", summary: "Control agents from desktop and mobile.", kind: "Meta harness"),
            .init(repository: "superset-sh/superset", name: "Superset", summary: "Terminals and workspaces for coding agents.", kind: "Meta harness")
        ]
    ]

    struct GitHubRepository: Decodable {
        let full_name: String
        let name: String
        let description: String?
        let stargazers_count: Int
        let archived: Bool
        let fork: Bool
        let topics: [String]?
        func entry(category: DiscoverCategory) -> DiscoverRepository? {
            guard DiscoverRepository.validRepository(full_name), !fork else { return nil }
            if category == .harnesses && ["awesome", "book", "tutorial", "course", "interview"].contains(where: { name.lowercased().contains($0) }) { return nil }
            let collection = name.lowercased().contains("awesome") || name.lowercased().contains("collection")
            return .init(repository: full_name, name: name, summary: description ?? "Explore the project’s documentation and setup guide.", kind: collection ? "Collection & directory" : category == .mcps ? "MCP project" : category == .skills ? "Skill project" : "Agent project", stars: max(0, stargazers_count), archived: archived)
        }
    }
    struct SearchResponse: Decodable { let items: [GitHubRepository]; let incomplete_results: Bool }
    struct FetchResult: Sendable { var entries: [DiscoverRepository]; var failures: Int }

    static func request(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("HarnessManager-Discover", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    static func fetch(_ category: DiscoverCategory) async -> FetchResult {
        var result = FetchResult(entries: [], failures: 0)
        // Only 1–2 searches per category; no auth or user credentials are needed.
        for query in category.queries {
            if Task.isCancelled { return result }
            do {
                var url = URLComponents(string: "https://api.github.com/search/repositories")!
                url.queryItems = [.init(name: "q", value: "\(query) stars:>100 archived:false fork:false"), .init(name: "sort", value: "stars"), .init(name: "order", value: "desc"), .init(name: "per_page", value: "40")]
                let response = try JSONDecoder().decode(SearchResponse.self, from: await request(url.url!))
                result.entries += response.items.compactMap { $0.entry(category: category) }
                if response.incomplete_results { result.failures += 1 }
            } catch { result.failures += 1 }
        }
        // Explicit selections remain discoverable even when they have no topic tags.
        for seed in seeds[category] ?? [] where !result.entries.contains(where: { $0.id == seed.id }) {
            if Task.isCancelled { return result }
            do {
                let data = try await request(URL(string: "https://api.github.com/repos/\(seed.repository)")!)
                if let entry = try JSONDecoder().decode(GitHubRepository.self, from: data).entry(category: category) { result.entries.append(entry) }
            } catch { result.failures += 1 }
        }
        return result
    }

    static func merge(category: DiscoverCategory, previous: [DiscoverRepository], incoming: [DiscoverRepository]) -> [DiscoverRepository] {
        var entries: [String: DiscoverRepository] = [:]
        for entry in previous + incoming where DiscoverRepository.validRepository(entry.repository) { entries[entry.id] = entry }
        for seed in seeds[category] ?? [] {
            var entry = entries[seed.id] ?? seed
            entry.name = seed.name; entry.summary = seed.summary; entry.kind = seed.kind
            entries[seed.id] = entry
        }
        let seedIDs = Set((seeds[category] ?? []).map(\.id))
        let ranked = DiscoverRepository.sorted(Array(entries.values))
        let popular = Array(ranked.filter { !seedIDs.contains($0.id) && !$0.archived }.prefix(80))
        return DiscoverRepository.sorted(popular + ranked.filter { seedIDs.contains($0.id) })
    }
}

@Observable @MainActor
final class DiscoverCatalogModel {
    var entries: [DiscoverCategory: [DiscoverRepository]] = DiscoverCatalogService.seeds
    var loading: Set<DiscoverCategory> = []
    var errors: [DiscoverCategory: String] = [:]
    var refreshed: [DiscoverCategory: Date] = [:]
    private var attempted: [DiscoverCategory: Date] = [:]
    private let cacheURL: URL
    private struct Cache: Codable {
        let entries: [DiscoverCategory: [DiscoverRepository]]
        let refreshed: [DiscoverCategory: Date]
    }

    init(cacheURL: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("HarnessManager/discover-v1.json")) {
        self.cacheURL = cacheURL
        if let data = try? Data(contentsOf: cacheURL), let cache = try? JSONDecoder().decode(Cache.self, from: data) {
            for category in DiscoverCategory.allCases {
                entries[category] = DiscoverCatalogService.merge(category: category, previous: [], incoming: cache.entries[category] ?? [])
            }
            refreshed = cache.refreshed
        }
    }

    func refresh(_ category: DiscoverCategory, force: Bool = false) async {
        guard !loading.contains(category) else { return }
        if let last = attempted[category], Date().timeIntervalSince(last) < 60 { return }
        if !force, let last = refreshed[category], Date().timeIntervalSince(last) < 86400 { return }
        attempted[category] = Date(); loading.insert(category); errors[category] = nil
        defer { loading.remove(category) }
        let result = await DiscoverCatalogService.fetch(category)
        guard !Task.isCancelled else { attempted[category] = nil; return }
        entries[category] = DiscoverCatalogService.merge(category: category, previous: entries[category] ?? [], incoming: result.entries)
        if result.failures > 0 {
            errors[category] = "Some GitHub data is unavailable or rate limited. Saved results remain available. Try refreshing in a few minutes."
        } else { refreshed[category] = Date() }
        do {
            try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(Cache(entries: entries, refreshed: refreshed)).write(to: cacheURL, options: .atomic)
        } catch {
            errors[category] = "Results loaded, but couldn’t be saved for offline use."
        }
    }
}
