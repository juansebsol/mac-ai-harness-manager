import SwiftUI

@Observable @MainActor
final class HarnessNewsModel {
    var articles: [HarnessArticle] = []
    var loading = false
    var failures: [String] = []
    var refreshed: Date?
    private var loaded = false
    private static let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("HarnessManager/news-v1.json")
    private struct Cache: Codable { let date: Date; let articles: [HarnessArticle] }

    func load() {
        guard !loaded else { return }; loaded = true
        if let data = try? Data(contentsOf: Self.cacheURL), let cache = try? JSONDecoder().decode(Cache.self, from: data) { articles = cache.articles; refreshed = cache.date }
    }

    func refresh() async {
        guard !loading else { return }
        loading = true; failures = []
        defer { loading = false }
        var successes = 0
        await withTaskGroup(of: (String, [HarnessArticle]?).self) { group in
            for source in HarnessNewsService.sources { group.addTask { (source.id, try? await HarnessNewsService.fetch(source)) } }
            for await (id, result) in group {
                if let result { articles.removeAll { $0.sourceID == id }; articles += result; successes += 1 }
                else { failures.append(HarnessNewsService.sources.first { $0.id == id }!.name) }
            }
        }
        var seen = Set<String>()
        articles = articles.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }.filter { seen.insert($0.id).inserted }
        articles = Array(articles.prefix(200))
        if successes > 0 {
            refreshed = Date()
            try? FileManager.default.createDirectory(at: Self.cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let data = try? JSONEncoder().encode(Cache(date: refreshed!, articles: articles)) { try? data.write(to: Self.cacheURL, options: .atomic) }
        }
    }
}

struct HarnessNewsView: View {
    @Environment(AppState.self) private var appState
    @State private var model = HarnessNewsModel()
    @State private var search = ""
    @State private var source = "all"
    @State private var category: NewsCategory? = .news
    @State private var showSources = false
    private var visible: [HarnessArticle] {
        model.articles.filter {
            (source == "all" || $0.sourceID == source) && (category == nil || $0.category == category) &&
            (search.isEmpty || "\($0.title) \($0.source) \($0.summary)".localizedCaseInsensitiveContains(search))
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 22) {
                PageHeading(eyebrow: "THE HARNESS BRIEFING", title: "A little ahead of the curve.", subtitle: "New tools, thoughtful reads, and releases. Straight from the source.")
                HStack {
                    FilterChip(title: "Latest", isSelected: category == nil) { category = nil }
                    ForEach(NewsCategory.allCases, id: \.self) { item in FilterChip(title: item.rawValue, isSelected: category == item) { category = item } }
                    Spacer()
                    Picker("Source", selection: $source) {
                        Text("All sources").tag("all")
                        ForEach(HarnessNewsService.sources) { Text($0.name).tag($0.id) }
                    }.labelsHidden().frame(width: 170)
                }
            }.padding(28)
            Divider()
            if !model.failures.isEmpty {
                Label("Couldn’t reach \(model.failures.joined(separator: ", ")). Previous stories stay available. Refresh to retry.", systemImage: "wifi.exclamationmark")
                    .font(.caption).foregroundStyle(.secondary).padding(16)
            }
            if visible.isEmpty {
                ContentUnavailableView(model.loading ? "Gathering the latest…" : "No matching stories", systemImage: "newspaper", description: Text("Choose another source or clear your search. Refresh to check the feeds."))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(visible) { article in
                            Link(destination: article.url) {
                                HStack(alignment: .top, spacing: 20) {
                                    Image(systemName: article.category == .release ? "shippingbox" : article.category == .community ? "bubble.left.and.bubble.right" : "text.alignleft")
                                        .font(.system(size: 19)).foregroundStyle(Color.accentColor).frame(width: 44, height: 44)
                                        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 7) {
                                            Text(article.source).fontWeight(.semibold)
                                            Text("/")
                                            Text(article.category.rawValue)
                                            Spacer()
                                            Text(article.date?.formatted(date: .abbreviated, time: .omitted) ?? "Date not provided")
                                        }.font(.system(size: 10)).foregroundStyle(.secondary)
                                        Text(article.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(.primary).lineLimit(2)
                                        Text(article.summary).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
                                    }
                                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary).padding(.top, 3)
                                }.padding(.vertical, 22).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            Divider()
                        }
                    }.padding(.horizontal, 28)
                }
            }
            Divider()
            HStack {
                Button("About the sources", systemImage: "info.circle") { showSources = true }.buttonStyle(.plain)
                Spacer()
                if model.loading { ProgressView().controlSize(.mini) }
                if let date = model.refreshed { Text("Last fetched \(date.formatted(date: .abbreviated, time: .shortened))") }
            }.font(.caption).foregroundStyle(.secondary).padding(16)
        }
        .navigationTitle("Harness news")
        .searchable(text: $search, prompt: "Search stories and tools")
        .toolbar { Button { Task { await model.refresh() } } label: { Label("Refresh news", systemImage: "arrow.clockwise") }.disabled(model.loading) }
        .task {
            if appState.isMarketingCapture { model.articles = MarketingCapture.news; return }
            model.load()
            if model.refreshed == nil || Date().timeIntervalSince(model.refreshed!) > 900 { await model.refresh() }
        }
        .sheet(isPresented: $showSources) {
            VStack(alignment: .leading, spacing: 16) {
                Text("A wider view of the ecosystem.").font(.title2.weight(.semibold))
                Text("Publisher feeds are filtered for coding tools and harnesses. Community stories are Hacker News discussions, not verified announcements. Releases come directly from the projects on GitHub.").foregroundStyle(.secondary)
                ForEach(HarnessNewsService.sources) { item in HStack { Text(item.name); Spacer(); Link(item.category.rawValue, destination: item.url) } }
                Text("Fetched when you open News, then cached on this Mac. Every headline opens its original source. No AI-generated stories.").font(.caption).foregroundStyle(.secondary)
                Button("Done") { showSources = false }.keyboardShortcut(.defaultAction).frame(maxWidth: .infinity, alignment: .trailing)
            }.padding(28).frame(width: 520)
        }
    }
}
