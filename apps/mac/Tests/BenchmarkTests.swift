import Foundation

@main struct BenchmarkTests {
    static func main() throws {
        let fixture = #"{"data":[{"id":"a/free","name":"Free model","pricing":{"input":0,"output":0,"unit":"usd_per_million_tokens"},"benchmarks":{"artificial_analysis":{"intelligence":null}}},{"id":"b/model","name":"Scored model","pricing":{"input":2,"output":4,"unit":"usd_per_million_tokens"},"benchmarks":{"artificial_analysis":{"intelligence":52.7}},"url":"javascript:alert(1)"}],"meta":{"total":2,"count":2,"has_more":false}}"#
        let intelligence = BenchmarkDefinition.catalog[0]
        let scores = try BenchmarkParser.parse(Data(fixture.utf8), metric: intelligence)
        precondition(scores.entries.count == 1 && scores.entries[0].value == 52.7)
        precondition(scores.entries[0].sourceURL == nil)
        let empty = try BenchmarkParser.parse(Data(#"{"data":[],"meta":{"total":0,"count":0,"has_more":false}}"#.utf8), metric: intelligence)
        precondition(empty.entries.isEmpty)
        for invalid in [#"{"error":"unavailable"}"#, #"{"data":[],"meta":{"total":5,"count":1,"has_more":true}}"#] {
            do { _ = try BenchmarkParser.parse(Data(invalid.utf8), metric: intelligence); fatalError("Accepted invalid response") } catch {}
        }
        let cached = try JSONDecoder().decode(BenchmarkSnapshot.self, from: JSONEncoder().encode(scores))
        precondition(cached.entries.count == 1 && cached.fetchedAt == scores.fetchedAt)
        let rankingFixture = #"{"title":"Coding","metric":"Index","answer":"Published assessment","count":2,"data":[{"rank":2,"metric_display":"81.6","metric_value":81.6,"id":"a/model","name":"Maker: Model","url":"javascript:bad"},{"rank":4,"metric_display":"Not scored","metric_value":null,"id":"b/model","name":"Another model"}]}"#
        let ranking = try RankingParser.parse(Data(rankingFixture.utf8))
        precondition(ranking.entries.map(\.rank) == [2, 4])
        precondition(ranking.entries.map(\.metricValue) == [81.6, nil])
        precondition(ranking.entries[1].metricDisplay == "Not scored")
        precondition(ranking.entries[0].sourceURL == nil)
        let rankingCache = try JSONDecoder().decode(RankingSnapshot.self, from: JSONEncoder().encode(ranking))
        precondition(rankingCache.entries[0].metricValue == 81.6)
        for file in CommandLine.arguments.dropFirst() {
            let data = try Data(contentsOf: URL(fileURLWithPath: file))
            for metric in BenchmarkDefinition.catalog {
                let result = try BenchmarkParser.parse(data, metric: metric)
                precondition(!result.entries.isEmpty)
                print("PASS live payload: \(metric.name), \(result.entries.count) scored models")
            }
        }
        print("PASS: null exclusion, raw units, published ranking order and numeric values, URL safety, invalid/empty responses, cache round trips")
    }
}
