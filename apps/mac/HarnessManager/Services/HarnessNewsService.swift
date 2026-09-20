import Foundation

enum NewsCategory: String, Codable, CaseIterable, Sendable {
    case news = "News & ideas", community = "Community", release = "Releases"
}

struct HarnessArticle: Identifiable, Codable, Sendable {
    let id: String
    let sourceID: String
    let source: String
    let category: NewsCategory
    let title: String
    let url: URL
    let date: Date?
    let summary: String
}

struct HarnessNewsSource: Identifiable, Sendable {
    enum Format: Sendable { case feed, hackerNews, releases }
    let id: String
    let name: String
    let url: URL
    let category: NewsCategory
    let format: Format
    var filterForHarnesses = true
}

enum HarnessNewsService {
    static let sources: [HarnessNewsSource] = [
        .init(id: "openai", name: "OpenAI", url: URL(string: "https://openai.com/news/rss.xml")!, category: .news, format: .feed),
        .init(id: "google", name: "Google Developers", url: URL(string: "https://developers.googleblog.com/feeds/posts/default?alt=rss")!, category: .news, format: .feed),
        .init(id: "simon", name: "Simon Willison", url: URL(string: "https://simonwillison.net/atom/everything/")!, category: .news, format: .feed),
        .init(id: "hn", name: "Hacker News", url: URL(string: "https://hn.algolia.com/api/v1/search_by_date?query=coding%20agent&tags=story&hitsPerPage=40")!, category: .community, format: .hackerNews),
        .init(id: "claude-releases", name: "Claude Code", url: URL(string: "https://api.github.com/repos/anthropics/claude-code/releases?per_page=12")!, category: .release, format: .releases, filterForHarnesses: false),
        .init(id: "codex-releases", name: "Codex", url: URL(string: "https://api.github.com/repos/openai/codex/releases?per_page=12")!, category: .release, format: .releases, filterForHarnesses: false),
        .init(id: "gemini-releases", name: "Gemini CLI", url: URL(string: "https://api.github.com/repos/google-gemini/gemini-cli/releases?per_page=12")!, category: .release, format: .releases, filterForHarnesses: false)
    ]

    static func isRelevant(_ text: String) -> Bool {
        let terms = ["codex", "claude code", "gemini cli", "antigravity", "coding agent", "coding harness", "agent harness", "agentic engineering", "agentic coding", "opencode", "open code", "openhands", "aider", "cursor", "kiro", "mistral vibe"]
        return terms.contains { text.localizedCaseInsensitiveContains($0) }
    }

    static func safeURL(_ value: String) -> URL? {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)), url.scheme == "https", url.host != nil else { return nil }
        return url
    }

    static func plainText(_ value: String) -> String {
        var text = value.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        for (encoded, decoded) in [("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&nbsp;", " "), ("&mdash;", "-"), ("&ndash;", "-"), ("&ldquo;", "“"), ("&rdquo;", "”"), ("&lsquo;", "‘"), ("&rsquo;", "’"), ("&#x27;", "'")] { text = text.replacingOccurrences(of: encoded, with: decoded) }
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        return text
    }

    static func parseDate(_ value: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) { return date }
        iso.formatOptions.insert(.withFractionalSeconds)
        if let date = iso.date(from: value) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, d MMM yyyy HH:mm:ss Z", "yyyy-MM-dd'T'HH:mm:ssXXXXX"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value.trimmingCharacters(in: .whitespacesAndNewlines)) { return date }
        }
        return nil
    }

    static func fetch(_ source: HarnessNewsSource) async throws -> [HarnessArticle] {
        var request = URLRequest(url: source.url, timeoutInterval: 20)
        request.setValue("HarnessManager/0.1 (+https://github.com/juansebsol/mac-ai-harness-manager)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 5_000_000 else { throw URLError(.badServerResponse) }
        return try parse(data, source: source)
    }

    static func parse(_ data: Data, source: HarnessNewsSource) throws -> [HarnessArticle] {
        switch source.format {
        case .feed:
            let delegate = HarnessFeedParser(source: source)
            let parser = XMLParser(data: data)
            parser.shouldResolveExternalEntities = false
            parser.delegate = delegate
            guard parser.parse() else { throw parser.parserError ?? URLError(.cannotParseResponse) }
            return delegate.articles
        case .releases:
            struct Release: Decodable { let name: String?; let tag_name: String; let html_url: String; let published_at: String?; let body: String?; let prerelease: Bool; let draft: Bool }
            return try JSONDecoder().decode([Release].self, from: data).compactMap { item in
                guard !item.draft, !item.prerelease, let date = item.published_at.flatMap(parseDate), let url = safeURL(item.html_url), url.host == "github.com" else { return nil }
                let title = item.name?.isEmpty == false ? item.name! : item.tag_name
                let body = (item.body ?? "Read the official release notes.").replacingOccurrences(of: "[#*`]", with: "", options: .regularExpression)
                return article(source: source, title: title, url: url, date: date, summary: body)
            }
        case .hackerNews:
            struct Response: Decodable { let hits: [Hit] }
            struct Hit: Decodable { let objectID: String; let title: String?; let created_at: String; let points: Int?; let url: String? }
            return try JSONDecoder().decode(Response.self, from: data).hits.compactMap { hit in
                guard let title = hit.title, isRelevant(title), (hit.points ?? 0) >= 2, let date = parseDate(hit.created_at), let url = safeURL("https://news.ycombinator.com/item?id=\(hit.objectID)") else { return nil }
                let host = hit.url.flatMap(safeURL)?.host ?? "news.ycombinator.com"
                return article(source: source, title: title, url: url, date: date, summary: "Community discussion · \(hit.points ?? 0) points · \(host)")
            }
        }
    }

    static func article(source: HarnessNewsSource, title: String, url: URL, date: Date?, summary: String) -> HarnessArticle {
        // Brief excerpts only. Full articles remain on the publisher’s website.
        let words = plainText(summary).split(separator: " ")
        let excerpt = words.prefix(45).joined(separator: " ") + (words.count > 45 ? "…" : "")
        return HarnessArticle(id: url.absoluteString, sourceID: source.id, source: source.name, category: source.category, title: plainText(title), url: url, date: date, summary: excerpt)
    }
}

private final class HarnessFeedParser: NSObject, XMLParserDelegate {
    let source: HarnessNewsSource
    var articles: [HarnessArticle] = []
    private var inside = false
    private var field = ""
    private var values: [String: String] = [:]
    init(source: HarnessNewsSource) { self.source = source }
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        if name == "item" || name == "entry" { inside = true; values = [:] }
        guard inside else { return }
        field = name
        if name == "link", let href = attributes["href"], attributes["rel"] == nil || attributes["rel"] == "alternate" { values["link"] = href }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { if inside { values[field, default: ""] += string } }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) { if let value = String(data: CDATABlock, encoding: .utf8) { self.parser(parser, foundCharacters: value) } }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        guard name == "item" || name == "entry" else { return }
        inside = false
        let title = values["title"] ?? ""
        let summary = values["description"] ?? values["summary"] ?? values["content"] ?? ""
        guard !title.isEmpty, let url = HarnessNewsService.safeURL(values["link"] ?? ""), !source.filterForHarnesses || HarnessNewsService.isRelevant(title + " " + HarnessNewsService.plainText(summary)) else { return }
        let date = HarnessNewsService.parseDate(values["pubDate"] ?? values["published"] ?? values["updated"] ?? values["dc:date"] ?? "")
        articles.append(HarnessNewsService.article(source: source, title: title, url: url, date: date, summary: summary))
    }
}
