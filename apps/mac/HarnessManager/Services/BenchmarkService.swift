import Foundation
import Observation

struct BenchmarkDefinition: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let category: String
    let summary: String
    var url: URL { URL(string: "https://modelgrep.com/api")! }
    var apiURL: URL { URL(string: "https://modelgrep.com/api/v1/models?sort=\(id)&limit=200")! }
    var lowerIsBetter: Bool { id == "latency" }
    static let catalog: [Self] = [
        .init(id: "intelligence", name: "Intelligence", category: "Intelligence index", summary: "Artificial Analysis Intelligence Index, provided by Modelgrep. Higher is better."),
        .init(id: "coding", name: "Coding", category: "Coding index", summary: "Artificial Analysis Coding Index, provided by Modelgrep. Higher is better."),
        .init(id: "agentic", name: "Agentic", category: "Agentic index", summary: "Artificial Analysis Agentic Index, provided by Modelgrep. Higher is better."),
        .init(id: "design", name: "Design", category: "Design Arena Elo", summary: "Design Arena Elo as reported by Modelgrep. Categories can differ between models; see each result’s context."),
        .init(id: "throughput", name: "Output speed", category: "Tokens / second", summary: "Median output throughput from Modelgrep’s performance data. Higher is faster."),
        .init(id: "latency", name: "Latency", category: "Milliseconds", summary: "Median time to first token from Modelgrep’s performance data. Lower is faster."),
        .init(id: "context", name: "Context window", category: "Tokens", summary: "Reported context capacity. Larger windows do not necessarily mean better long-context reasoning.")
    ]
}

struct RankingCollection: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let group: String
    let icon: String
    var apiURL: URL { URL(string: "https://modelgrep.com/api/v1/rankings/\(id)")! }

    static let catalog: [Self] = [
        .init(id: "smartest", title: "Smartest", subtitle: "Highest intelligence index", group: "Start here", icon: "sparkle"),
        .init(id: "coding", title: "Coding", subtitle: "Real software tasks", group: "Start here", icon: "chevron.left.forwardslash.chevron.right"),
        .init(id: "agents", title: "Agents", subtitle: "Tool use and planning", group: "Start here", icon: "point.3.connected.trianglepath.dotted"),
        .init(id: "fastest", title: "Fastest", subtitle: "Most output per second", group: "Start here", icon: "bolt"),
        .init(id: "lowest-latency", title: "Low latency", subtitle: "Fast to first token", group: "Start here", icon: "timer"),
        .init(id: "cheapest", title: "Cheapest", subtitle: "Lowest token cost", group: "Start here", icon: "dollarsign.circle"),
        .init(id: "free", title: "Free", subtitle: "Capable at zero cost", group: "Start here", icon: "gift"),
        .init(id: "design", title: "Design", subtitle: "Design and frontend output", group: "Build", icon: "paintpalette"),
        .init(id: "ui-components", title: "UI components", subtitle: "React and component work", group: "Build", icon: "rectangle.3.group"),
        .init(id: "fullstack", title: "Full-stack apps", subtitle: "End-to-end app building", group: "Build", icon: "square.stack.3d.up"),
        .init(id: "mobile-apps", title: "Mobile apps", subtitle: "Native and mobile work", group: "Build", icon: "iphone"),
        .init(id: "tool-calling", title: "Tool calling", subtitle: "Functions that hold up", group: "Build", icon: "wrench.and.screwdriver"),
        .init(id: "long-context-reasoning", title: "Long-context reasoning", subtitle: "Reasoning over large inputs", group: "Build", icon: "text.book.closed"),
        .init(id: "reasoning", title: "Reasoning", subtitle: "Deep multi-step thinking", group: "Think", icon: "brain"),
        .init(id: "math", title: "Math", subtitle: "Competition math", group: "Think", icon: "function"),
        .init(id: "science", title: "Science", subtitle: "Scientific reasoning", group: "Think", icon: "atom"),
        .init(id: "writing", title: "Writing", subtitle: "Long-form and creative", group: "Think", icon: "text.alignleft"),
        .init(id: "instruction-following", title: "Instruction following", subtitle: "Follows detailed constraints", group: "Think", icon: "checklist"),
        .init(id: "rag", title: "RAG", subtitle: "Retrieval pipelines", group: "Think", icon: "magnifyingglass"),
        .init(id: "sql", title: "SQL and analysis", subtitle: "Structured data work", group: "Think", icon: "cylinder.split.1x2"),
        .init(id: "local", title: "Local", subtitle: "Runs on your hardware", group: "Run", icon: "desktopcomputer"),
        .init(id: "open-source", title: "Open-source", subtitle: "Self-hostable weights", group: "Run", icon: "lock.open"),
        .init(id: "small", title: "Small and fast", subtitle: "Efficient tier", group: "Run", icon: "arrow.down.right.and.arrow.up.left"),
        .init(id: "long-context", title: "Long context", subtitle: "Largest context windows", group: "Run", icon: "text.append"),
        .init(id: "vision", title: "Vision", subtitle: "Images and documents", group: "Run", icon: "eye"),
        .init(id: "uncensored", title: "Uncensored", subtitle: "No provider moderation layer", group: "Run", icon: "theatermasks"),
        .init(id: "dataviz", title: "Data visualization", subtitle: "Charts and dashboards", group: "Specialist", icon: "chart.xyaxis.line"),
        .init(id: "svg", title: "SVG", subtitle: "Vector graphics as code", group: "Specialist", icon: "pencil.and.outline"),
        .init(id: "game-dev", title: "Game development", subtitle: "Playable game code", group: "Specialist", icon: "gamecontroller"),
        .init(id: "3d", title: "3D", subtitle: "Scenes and geometry", group: "Specialist", icon: "cube"),
        .init(id: "roleplay", title: "Roleplay", subtitle: "Long-context character chat", group: "Specialist", icon: "theatermask.and.paintbrush")
    ]

    static let groups = ["Start here", "Build", "Think", "Run", "Specialist"]
}

struct ModelgrepModel: Decodable {
    struct Pricing: Decodable { let input: Double?; let output: Double?; let unit: String? }
    struct Performance: Decodable { let throughput_tps: Double?; let latency_ms: Double? }
    struct Benchmarks: Decodable {
        struct Design: Decodable { let elo: Double?; let category: String? }
        let artificial_analysis: [String: Double?]?
        let design_arena: Design?
    }
    let id: String
    let name: String
    let maker: String?
    let context_length: Double?
    let pricing: Pricing?
    let performance: Performance?
    let benchmarks: Benchmarks?
    let url: String?

    func score(for metric: String) -> Double? {
        switch metric {
        case "design": return benchmarks?.design_arena?.elo
        case "throughput": return performance?.throughput_tps
        case "latency": return performance?.latency_ms
        case "context": return context_length
        default: return benchmarks?.artificial_analysis?[metric] ?? nil
        }
    }
}

struct BenchmarkEntry: Codable, Identifiable, Sendable {
    let rank: Int
    let modelId: String
    let name: String
    let value: Double
    let notes: String?
    let source: String?
    var id: String { modelId }
    var chartLabel: String { "\(rank). \(name)" }
    var sourceURL: URL? {
        guard let source, let url = URL(string: source), url.scheme == "https", url.host == "modelgrep.com" else { return nil }
        return url
    }
}

struct BenchmarkSnapshot: Codable, Sendable {
    let entries: [BenchmarkEntry]
    let fetchedAt: Date
    let fetchedCount: Int
    let total: Int
    let hasMore: Bool
}

struct RankingEntry: Codable, Identifiable, Sendable {
    let rank: Int
    let modelId: String
    let name: String
    let maker: String?
    let metricDisplay: String
    let metricValue: Double?
    let notes: String?
    let source: String?
    var id: String { modelId }
    var sourceURL: URL? {
        guard let source, let url = URL(string: source), url.scheme == "https", url.host == "modelgrep.com" else { return nil }
        return url
    }
}

struct RankingSnapshot: Codable, Sendable {
    let title: String
    let metric: String
    let answer: String
    let entries: [RankingEntry]
    let fetchedAt: Date
}

enum BenchmarkParser {
    struct Response: Decodable {
        struct Meta: Decodable { let total: Int; let count: Int; let has_more: Bool }
        let data: [ModelgrepModel]
        let meta: Meta
    }
    static func parse(_ data: Data, metric: BenchmarkDefinition) throws -> BenchmarkSnapshot {
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard response.data.count <= 200, response.meta.count == response.data.count,
              response.meta.total >= response.meta.count,
              response.data.allSatisfy({ !$0.id.isEmpty && !$0.name.isEmpty }) else {
            throw NSError(domain: "Benchmarks", code: 1, userInfo: [NSLocalizedDescriptionKey: "Modelgrep returned an invalid catalog response."])
        }
        let scored = response.data.compactMap { model -> (ModelgrepModel, Double)? in
            guard let value = model.score(for: metric.id), value.isFinite, value >= 0 else { return nil }
            return (model, value)
        }.sorted {
            if $0.1 == $1.1 { return $0.0.id < $1.0.id }
            return metric.lowerIsBetter ? $0.1 < $1.1 : $0.1 > $1.1
        }
        var seen = Set<String>()
        let unique = scored.filter { seen.insert($0.0.id).inserted }
        let entries = unique.enumerated().map { index, item in
            let (model, value) = item
            var context = [model.maker ?? ""]
            if metric.id == "design", let category = model.benchmarks?.design_arena?.category { context.append("Design category: \(category)") }
            if let price = model.pricing, price.unit == "usd_per_million_tokens" {
                if let input = price.input { context.append("Input $\(input.formatted(.number.precision(.fractionLength(0...4)))) / 1M") }
                if let output = price.output { context.append("Output $\(output.formatted(.number.precision(.fractionLength(0...4)))) / 1M") }
            }
            return BenchmarkEntry(rank: index + 1, modelId: model.id, name: model.name, value: value, notes: context.filter { !$0.isEmpty }.joined(separator: " · "), source: model.url)
        }
        return BenchmarkSnapshot(entries: entries, fetchedAt: Date(), fetchedCount: response.meta.count, total: response.meta.total, hasMore: response.meta.has_more)
    }
}

enum RankingParser {
    struct Model: Decodable {
        let rank: Int
        let metric_display: String
        let metric_value: Double?
        let id: String
        let name: String
        let maker: String?
        let description: String?
        let url: String?
    }
    struct Response: Decodable {
        let title: String
        let metric: String
        let answer: String
        let count: Int
        let data: [Model]
    }
    static func parse(_ data: Data) throws -> RankingSnapshot {
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard response.count == response.data.count, !response.title.isEmpty, !response.metric.isEmpty,
              response.data.allSatisfy({ $0.rank > 0 && !$0.id.isEmpty && !$0.name.isEmpty }) else {
            throw NSError(domain: "Rankings", code: 1, userInfo: [NSLocalizedDescriptionKey: "Modelgrep returned an invalid ranking response."])
        }
        return RankingSnapshot(
            title: response.title,
            metric: response.metric,
            answer: response.answer,
            entries: response.data.map { RankingEntry(rank: $0.rank, modelId: $0.id, name: $0.name, maker: $0.maker, metricDisplay: $0.metric_display, metricValue: $0.metric_value?.isFinite == true ? $0.metric_value : nil, notes: $0.description, source: $0.url) },
            fetchedAt: Date()
        )
    }
}

@MainActor @Observable
final class BenchmarkStore {
    private(set) var snapshots: [String: BenchmarkSnapshot] = [:]
    private(set) var rankingSnapshots: [String: RankingSnapshot] = [:]
    private(set) var loading: Set<String> = []
    private(set) var errors: [String: String] = [:]
    private var attempted: [String: Date] = [:]
    private let cacheURL: URL
    private let inMemory: Bool
    static let refreshInterval: TimeInterval = 60 * 60

    init(inMemory: Bool = false) {
        self.inMemory = inMemory
        cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HarnessManager/modelgrep-v5.json")
        if !inMemory, let data = try? Data(contentsOf: cacheURL), let cache = try? JSONDecoder().decode(Cache.self, from: data) {
            snapshots = cache.metrics
            rankingSnapshots = cache.rankings
        }
    }

    func refresh(_ benchmark: BenchmarkDefinition, force: Bool = false) async {
        let id = benchmark.id
        guard !loading.contains(id) else { return }
        if !force, let cached = snapshots[id], Date().timeIntervalSince(cached.fetchedAt) < Self.refreshInterval { return }
        if !force, let last = attempted[id], Date().timeIntervalSince(last) < 60 { return }
        attempted[id] = Date()
        loading.insert(id)
        defer { loading.remove(id) }
        do {
            var request = URLRequest(url: benchmark.apiURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("HarnessManager-Benchmarks", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            guard response.statusCode == 200 else {
                let message = response.statusCode == 429 ? "Modelgrep is rate limiting requests. Try again later." : "Modelgrep returned HTTP \(response.statusCode). Try again later."
                throw NSError(domain: "Benchmarks", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
            }
            snapshots[id] = try BenchmarkParser.parse(data, metric: benchmark)
            errors[id] = nil
            guard !inMemory else { return }
            do {
                try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try JSONEncoder().encode(Cache(metrics: snapshots, rankings: rankingSnapshots)).write(to: cacheURL, options: .atomic)
            } catch { errors[id] = "Live results loaded, but the offline cache could not be saved." }
        } catch is CancellationError { return }
        catch { if (error as? URLError)?.code != .cancelled { errors[id] = error.localizedDescription } }
    }

    func refresh(_ collection: RankingCollection, force: Bool = false) async {
        let id = "ranking-\(collection.id)"
        guard !loading.contains(id) else { return }
        if !force, let cached = rankingSnapshots[collection.id], Date().timeIntervalSince(cached.fetchedAt) < Self.refreshInterval { return }
        if !force, let last = attempted[id], Date().timeIntervalSince(last) < 60 { return }
        attempted[id] = Date()
        loading.insert(id)
        defer { loading.remove(id) }
        do {
            var request = URLRequest(url: collection.apiURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("HarnessManager-Rankings", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                throw NSError(domain: "Rankings", code: 1, userInfo: [NSLocalizedDescriptionKey: "Modelgrep could not load this collection. Try again later."])
            }
            rankingSnapshots[collection.id] = try RankingParser.parse(data)
            errors[id] = nil
            guard !inMemory else { return }
            do {
                try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try JSONEncoder().encode(Cache(metrics: snapshots, rankings: rankingSnapshots)).write(to: cacheURL, options: .atomic)
            } catch { errors[id] = "Live collection loaded, but the offline cache could not be saved." }
        } catch is CancellationError { return }
        catch { if (error as? URLError)?.code != .cancelled { errors[id] = error.localizedDescription } }
    }

    private struct Cache: Codable {
        let metrics: [String: BenchmarkSnapshot]
        let rankings: [String: RankingSnapshot]
    }
}
