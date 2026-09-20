import SwiftUI

struct HarnessRelease: Identifiable, Codable, Sendable {
    let id: String
    let source: String
    let title: String
    let url: URL
    let date: Date
    let summary: String
}

@Observable @MainActor
final class HarnessNewsModel {
    var releases: [HarnessRelease] = []
    var loading = false
    var failures: [String] = []
    var refreshed: Date?
    static let sources = [("Claude Code", "anthropics/claude-code"), ("Codex", "openai/codex"), ("Gemini CLI", "google-gemini/gemini-cli")]

    private static func excerpt(_ body: String) -> String {
        let lines = body.components(separatedBy: .newlines).filter { !$0.hasPrefix("#") && !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return String(lines.joined(separator: " ").replacingOccurrences(of: "`", with: "").prefix(500))
    }

    func refresh() async {
        guard !loading else { return }
        loading = true
        failures = []
        defer { loading = false }
        for (name, repo) in Self.sources {
            do {
                let url = URL(string: "https://api.github.com/repos/\(repo)/releases?per_page=12")!
                var request = URLRequest(url: url, timeoutInterval: 15)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                struct Release: Decodable {
                    let name: String?
                    let tag_name: String
                    let html_url: URL
                    let published_at: Date?
                    let body: String?
                    let prerelease: Bool
                    let draft: Bool
                }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let items = try decoder.decode([Release].self, from: data)
                let mapped = items.filter { !$0.draft && !$0.prerelease }.compactMap { item -> HarnessRelease? in
                    guard let date = item.published_at, item.html_url.scheme == "https", item.html_url.host == "github.com" else { return nil }
                    return HarnessRelease(id: item.html_url.absoluteString, source: name, title: item.name ?? item.tag_name, url: item.html_url, date: date, summary: Self.excerpt(item.body ?? "Read the official release notes."))
                }
                releases.removeAll { $0.source == name }
                releases.append(contentsOf: mapped)
            } catch { failures.append(name) }
        }
        releases.sort { $0.date > $1.date }
        if failures.isEmpty { refreshed = Date() }
    }
}

struct HarnessNewsView: View {
    @State private var model = HarnessNewsModel()
    @State private var search = ""
    @State private var source = "All sources"
    private var visible: [HarnessRelease] {
        model.releases.filter {
            (source == "All sources" || $0.source == source) &&
            (search.isEmpty || "\($0.title) \($0.source) \($0.summary)".localizedCaseInsensitiveContains(search))
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("The harness briefing").font(.system(size: 30, weight: .bold))
                Text("Official releases, in one place. Follow what’s changing in your coding tools.")
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    Picker("Source", selection: $source) {
                        Text("All sources").tag("All sources")
                        ForEach(HarnessNewsModel.sources, id: \.0) { Text($0.0).tag($0.0) }
                    }.frame(width: 220)
                    Spacer()
                    if model.loading { ProgressView().controlSize(.small) }
                    else if let date = model.refreshed {
                        Text("Fetched \(date.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.padding(24)
            Divider()
            if !model.failures.isEmpty {
                Label("Couldn’t refresh \(model.failures.joined(separator: ", ")). GitHub may be unavailable or rate limited. Try again shortly.", systemImage: "wifi.exclamationmark")
                    .font(.callout).foregroundStyle(.secondary).padding(16)
            }
            if visible.isEmpty {
                ContentUnavailableView(model.loading ? "Fetching official releases…" : "No releases to show", systemImage: "newspaper", description: Text("Try another source or search. Use Refresh to retry the feeds."))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(visible) { release in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(release.source).font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
                                    Text("·").foregroundStyle(.tertiary)
                                    Text(release.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Image(systemName: "arrow.up.right").foregroundStyle(.secondary)
                                }
                                Link(release.title, destination: release.url).font(.title3.weight(.semibold))
                                Text(release.summary).font(.callout).foregroundStyle(.secondary).lineLimit(4).textSelection(.enabled)
                            }.padding(24)
                            Divider().padding(.horizontal, 24)
                        }
                    }.frame(maxWidth: 900, alignment: .leading).frame(maxWidth: .infinity)
                }
            }
            Divider()
            HStack {
                Text("Discover more tools").font(.caption.weight(.medium))
                Spacer()
                Link("GitHub · coding agents", destination: URL(string: "https://github.com/topics/ai-coding-agent")!)
            }.font(.caption).padding(16)
        }
        .navigationTitle("Harness news")
        .searchable(text: $search, prompt: "Search release notes")
        .toolbar {
            Button { Task { await model.refresh() } } label: { Label("Refresh feeds", systemImage: "arrow.clockwise") }
                .disabled(model.loading)
        }
        .task { if model.releases.isEmpty { await model.refresh() } }
    }
}
