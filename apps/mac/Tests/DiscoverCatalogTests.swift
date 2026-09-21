import Foundation

@main struct DiscoverCatalogTests {
    static func main() async throws {
        let original = DiscoverRepository(repository: "example/project", name: "Project", summary: "Saved", kind: "Skill", stars: 100)
        let updated = DiscoverRepository(repository: "Example/Project", name: "Project", summary: "New", kind: "Skill", stars: 300)
        let archived = DiscoverRepository(repository: "example/old", name: "Old", summary: "", kind: "Skill", stars: 900, archived: true)
        let unknown = DiscoverRepository(repository: "example/new", name: "New", summary: "", kind: "Skill")
        let merged = DiscoverCatalogService.merge(category: .skills, previous: [original], incoming: [updated, archived, unknown])
        precondition(merged.filter { $0.id == original.id }.count == 1)
        precondition(merged.first?.stars == 300)
        precondition(!merged.contains { $0.id == archived.id })
        for seed in DiscoverCatalogService.seeds[.skills]! { precondition(merged.contains { $0.id == seed.id }) }
        let offline = DiscoverCatalogService.merge(category: .skills, previous: merged, incoming: [])
        precondition(offline.first?.stars == 300)
        precondition(DiscoverRepository.sorted([unknown, original, archived]).map(\.id) == [original.id, unknown.id, archived.id])
        precondition(!DiscoverRepository.validRepository("https://evil.example/x"))
        precondition(!DiscoverRepository.validRepository("owner/repo?redirect=x"))
        let fixture = Data(#"{"items":[{"full_name":"owner/repo","name":"repo","description":null,"stargazers_count":42,"archived":false,"fork":false}],"incomplete_results":true}"#.utf8)
        let response = try JSONDecoder().decode(DiscoverCatalogService.SearchResponse.self, from: fixture)
        precondition(response.incomplete_results)
        precondition(response.items[0].entry(category: .mcps)?.stars == 42)
        precondition(response.items[0].entry(category: .mcps)?.url.absoluteString == "https://github.com/owner/repo")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = directory.appendingPathComponent("catalog.json")
        try Data("not valid json".utf8).write(to: cache)
        let model = DiscoverCatalogModel(cacheURL: cache)
        let seedCount = model.entries[.skills]?.count
        precondition(seedCount == 10)
        if CommandLine.arguments.contains("--live") {
            for category in DiscoverCategory.allCases {
                let result = await DiscoverCatalogService.fetch(category)
                print("LIVE \(category.rawValue): \(result.entries.count) repositories; \(result.failures) source failures")
                precondition(!result.entries.isEmpty, "No live results for \(category)")
                print(result.entries.prefix(3).map { "\($0.repository): \($0.stars ?? 0) stars" }.joined(separator: "\n"))
            }
        }
        print("PASS: catalog ranking, deduplication, seed preservation, offline fallback, safe repository URLs, API decoding, corrupt cache recovery")
    }
}
