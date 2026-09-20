import Foundation

@main struct NewsFeedTests {
    static func main() throws {
        let source = HarnessNewsService.sources[0]
        let rss = """
        <rss><channel>
        <item><title>Introducing a coding agent</title><link>https://example.com/agent</link><pubDate>Thu, 10 Sep 2026 16:00:00 GMT</pubDate><description><![CDATA[<p>Real <b>harness</b> news &amp; ideas.</p>]]></description></item>
        <item><title>Weather report</title><link>https://example.com/weather</link><pubDate>Thu, 10 Sep 2026 16:00:00 GMT</pubDate><description>Rain today.</description></item>
        <item><title>Codex unsafe URL</title><link>javascript:alert(1)</link><description>Ignore this.</description></item>
        <item><title>Harness engineering without a date</title><link>https://example.com/undated</link><description>Coding agent tests.</description></item>
        </channel></rss>
        """
        let items = try HarnessNewsService.parse(Data(rss.utf8), source: source)
        precondition(items.count == 2, "Filter unrelated news and unsafe URLs")
        precondition(items[0].summary == "Real harness news & ideas.")
        precondition(items[0].date != nil && items[1].date == nil, "Never fabricate an undated publisher timestamp")
        let atom = """
        <feed xmlns="http://www.w3.org/2005/Atom"><entry><title>Claude Code &amp; tools</title><link rel="self" href="https://example.com/api"/><link rel="alternate" href="https://example.com/article"/><published>2026-09-18T23:57:57+00:00</published><summary type="html">&lt;p&gt;Coding agents.&lt;/p&gt;</summary></entry></feed>
        """
        let parsed = try HarnessNewsService.parse(Data(atom.utf8), source: source)
        precondition(parsed.count == 1 && parsed[0].url.absoluteString == "https://example.com/article")
        precondition(parsed[0].summary == "Coding agents.")
        let json = """
        [{"name":"Stable","tag_name":"v1","html_url":"https://github.com/openai/codex/releases/tag/v1","published_at":"2026-09-18T12:00:00Z","body":"## New version","prerelease":false,"draft":false},{"name":"Beta","tag_name":"v2","html_url":"https://github.com/openai/codex/releases/tag/v2","published_at":"2026-09-18T12:00:00Z","body":"Beta","prerelease":true,"draft":false}]
        """
        let releases = try HarnessNewsService.parse(Data(json.utf8), source: HarnessNewsService.sources[5])
        precondition(releases.count == 1)
        do { _ = try HarnessNewsService.parse(Data("<rss>broken".utf8), source: source); fatalError("Malformed feeds must fail") } catch { }
        for source in HarnessNewsService.sources where source.formatNameForTests != "release" {
            guard let folder = ProcessInfo.processInfo.environment["HARNESS_FEED_FIXTURES"] else { continue }
            let path = "\(folder)/harness-feed-\(source.id)"
            if let data = FileManager.default.contents(atPath: path) {
                let stories = try HarnessNewsService.parse(data, source: source)
                print("Verified live fixture \(source.name): \(stories.count) relevant stories")
                if source.id == "openai" || source.id == "google" { precondition(!stories.isEmpty) }
            }
        }
        print("News feed parsing, relevance, dates, release filtering, and safe-link tests passed")
    }
}

private extension HarnessNewsSource {
    var formatNameForTests: String { if case .releases = format { return "release" }; return "feed" }
}
