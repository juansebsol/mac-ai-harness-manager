import Foundation
import Security

@main struct UsageTests {
    @MainActor static func main() async throws {
        let payload = #"{"rateLimits":{"primary":{"usedPercent":99}},"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":25,"windowDurationMins":300,"resetsAt":2000000000},"secondary":{"usedPercent":0,"windowDurationMins":10080}},"review":{"limitName":"Code review","primary":{"usedPercent":110}},"unknown":{"primary":{"usedPercent":null}}}}"#
        let windows = try UsageParser.codex(Data(payload.utf8))
        precondition(windows.count == 3, "Multi-bucket values replace, rather than duplicate, legacy values")
        precondition(windows[0].remaining == 75 && windows[0].duration == "5-hour window")
        precondition(windows[0].resetsAt?.timeIntervalSince1970 == 2000000000)
        precondition(windows[1].remaining == 100 && windows[1].duration == "7-day window")
        precondition(windows[2].remaining == 0)
        let legacy = try UsageParser.codex(Data(#"{"rateLimits":{"primary":{"usedPercent":80}},"rateLimitsByLimitId":{}}"#.utf8))
        precondition(legacy.count == 1 && legacy[0].remaining == 20)
        let missing = try UsageParser.codex(Data(#"{"rateLimits":null}"#.utf8))
        precondition(missing.isEmpty, "Missing limits must not become zero usage")
        let unknownTokens = try UsageParser.tokens(Data(#"{"summary":{"lifetimeTokens":null}}"#.utf8))
        let zeroTokens = try UsageParser.tokens(Data(#"{"summary":{"lifetimeTokens":0}}"#.utf8))
        precondition(unknownTokens == nil && zeroTokens == 0)
        let key = try UsageParser.router(Data(#"{"data":{"usage":90,"usage_daily":0,"usage_monthly":4,"limit":10,"limit_remaining":6,"limit_reset":"monthly"}}"#.utf8))
        precondition(key.limitRemaining == 6 && key.usage == 90, "Lifetime spending must not be subtracted from a recurring budget")
        precondition(key.usageDaily == 0)
        let uncapped = try UsageParser.router(Data(#"{"data":{"usage":0,"limit":null,"limit_remaining":null}}"#.utf8))
        precondition(uncapped.limit == nil && uncapped.limitRemaining == nil && uncapped.usageMonthly == nil)
        let balance = try UsageParser.credits(Data(#"{"data":{"total_credits":150.5,"total_usage":25.25}}"#.utf8))
        precondition(balance.balance == 125.25 && balance.totalUsage == 25.25)
        let zeroBalance = try UsageParser.credits(Data(#"{"data":{"total_credits":25,"total_usage":25}}"#.utf8))
        precondition(zeroBalance.balance == 0)
        for invalid in [#"{"data":{"total_usage":1}}"#, #"{"data":{"total_credits":100}}"#, #"{"data":{"total_credits":-1,"total_usage":0}}"#, #"{"error":"forbidden"}"#] {
            do { _ = try UsageParser.credits(Data(invalid.utf8)); fatalError("Unknown credits became a balance") } catch {}
        }
        let suite = "HarnessUsageTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UsagePreferences(defaults: defaults)
        precondition(preferences.enabled(.openrouter))
        preferences.set(.openrouter, enabled: false)
        preferences.set(.google, enabled: false)
        let reloaded = UsagePreferences(defaults: defaults)
        precondition(!reloaded.enabled(.openrouter) && !reloaded.enabled(.google) && reloaded.enabled(.cursor))
        reloaded.set(.openrouter, enabled: true)
        precondition(UsagePreferences(defaults: defaults).enabled(.openrouter))
        precondition(UsageProvider.google.logo == "Logo-gemini-cli" && UsageProvider.google.live)
        print("PASS: account credit balance, zero versus unavailable, and persisted provider visibility")
        do { _ = try UsageParser.router(Data(#"{"error":"unauthorized"}"#.utf8)); fatalError("Accepted API error") } catch {}
        print("PASS: Codex multi-bucket precedence, legacy fallback, clamping, resets, unknown vs zero, OpenRouter recurring budgets and uncapped keys")
        let summary = Data(#"{"response":{"groups":[{"buckets":[{"bucketId":"gemini-5h","remainingFraction":0.75,"resetTime":"2026-09-22T12:00:00Z"},{"bucketId":"gemini-weekly","remainingFraction":0},{"bucketId":"3p-5h","remainingFraction":1},{"bucketId":"3p-weekly","remainingFraction":null},{"bucketId":"future-bucket","remainingFraction":0},42]}]}}"#.utf8)
        let pools = DesktopUsageParser.antigravitySummary(summary)!
        precondition(pools.count == 3 && pools[0].remaining == 75 && pools[1].remaining == 0 && pools[2].remaining == 100)
        precondition(pools[0].resetsAt != nil)
        precondition(DesktopUsageParser.antigravitySummary(Data(#"{"groups":[]}"#.utf8))?.isEmpty == true)
        precondition(DesktopUsageParser.antigravitySummary(Data(#"{"error":"not supported"}"#.utf8)) == nil)
        let legacyPools = DesktopUsageParser.antigravityLegacy(Data(#"{"clientModelConfigs":[{"label":"Gemini Pro","quotaInfo":{"remainingFraction":0.5}},{"label":"Gemini Flash","quotaInfo":{"remainingFraction":0.8}},{"label":"Claude","quotaInfo":{"remainingFraction":1}},{"label":"Claude 2"}]}"#.utf8))
        precondition(legacyPools.count == 2 && legacyPools[0].remaining == 50 && legacyPools[1].remaining == 100)
        let cursor = try DesktopUsageParser.cursor(primary: Data(#"{"enabled":true,"billingCycleEnd":"2000000000000","planUsage":{"totalPercentUsed":25,"autoPercentUsed":0,"apiPercentUsed":50},"spendLimitUsage":{"individualUsed":400,"individualLimit":1000,"pooledUsed":999999}}"#.utf8), summary: nil, requests: nil)
        precondition(cursor.metrics.count == 4 && cursor.metrics[0].remaining == 75)
        precondition(cursor.metrics[1].used == 0 && cursor.metrics[3].used == 4 && cursor.metrics[3].remaining == 6)
        precondition(cursor.metrics[0].resetsAt?.timeIntervalSince1970 == 2000000000)
        let enterprise = try DesktopUsageParser.cursor(primary: nil, summary: Data(#"{"billingCycleEnd":"2026-10-01T00:00:00.000Z","individualUsage":{"onDemand":{"used":350,"limit":1000}},"teamUsage":{"onDemand":{"used":9000,"limit":10000}}}"#.utf8), requests: Data(#"{"gpt-4":{"numRequests":42,"maxRequestUsage":100}}"#.utf8))
        precondition(enterprise.metrics[0].remaining == 58 && enterprise.metrics[1].used == 3.5)
        precondition(enterprise.metrics[0].resetsAt != nil)
        for invalid in [#"{}"#, #"{"planUsage":{"limit":1000}}"#, #"{"planUsage":{"totalPercentUsed":true}}"#] {
            do { _ = try DesktopUsageParser.cursor(primary: Data(invalid.utf8), summary: nil, requests: nil); fatalError("Missing usage became zero") } catch {}
        }
        let authJSON = #"{"token":{"access_token":"fixture-access","refresh_token":"fixture-refresh"}}"#
        let wrappedAuth = "go-keyring-base64:" + Data(authJSON.utf8).base64EncodedString()
        let auth = try DesktopUsageCredentials.antigravityCredential(exitCode: 0, stdout: wrappedAuth)
        precondition(auth?.access == "fixture-access" && auth?.refresh == "fixture-refresh")
        let absentAuth = try DesktopUsageCredentials.antigravityCredential(exitCode: 44, stdout: "")
        precondition(absentAuth == nil)
        for failure: Int32 in [1, 36, 124, 143] {
            do {
                _ = try DesktopUsageCredentials.antigravityCredential(exitCode: failure, stdout: authJSON)
                fatalError("Denied or timed-out credentials were accepted")
            } catch {}
        }
        print("PASS: Antigravity Keychain credentials decode; missing, denied, and timed-out reads stay distinct")
        let processes = "123 /Applications/Antigravity.app/Contents/Resources/language_server_macos --ide_name antigravity --csrf_token=fixture --extension_server_port 5555\n456 /Applications/Windsurf.app/language_server_macos --ide_name windsurf --csrf_token other"
        let servers = AntigravityUsageClient.servers(processes)
        precondition(servers.count == 1 && servers[0].pid == 123 && servers[0].csrf == "fixture")
        precondition(AntigravityUsageClient.ports("p123\nn127.0.0.1:5555\nn*:5555\nn[::1]:6000\nn*:70000") == [5555, 6000])
        print("PASS: Cursor cents, personal/team scopes, request quotas, Antigravity shared pools, authoritative empty summaries, missing data, process and port filtering")
        let claude = try AdditionalUsageClient.parseClaude(["five_hour": ["utilization": 25.0], "seven_day": ["utilization": 0.0]])
        precondition(claude.metrics.count == 2 && claude.metrics[0].remaining == 75)
        let zai = try AdditionalUsageClient.parseZAI(["data": ["limits": [["type": "CREDIT_LIMIT", "percentage": 20, "unit": 3, "number": 5], ["type": "TIME_LIMIT", "currentValue": 4, "usage": 100]]]])
        precondition(zai.metrics[0].remaining == 80 && zai.metrics[1].remaining == 96)
        let mini = try AdditionalUsageClient.parseMiniMax(["model_remains": [["model_name": "text", "current_interval_total_count": 100, "current_interval_usage_count": 70]]])
        precondition(mini.metrics[0].used == 30 && mini.metrics[0].remaining == 70, "MiniMax usage_count means remaining")
        let costs = try AdditionalUsageClient.costAmounts(["data": [["results": [["amount": ["currency": "usd", "value": 2.5]], ["amount": ["currency": "eur", "value": 3]]]]]])
        precondition(costs["USD"] == 2.5 && costs["EUR"] == 3, "Never combine currencies")
        let google = try AdditionalUsageClient.googleAmounts(["timeSeries": [["metricKind": "DELTA", "metric": ["labels": ["model": "gemini"]], "points": [["value": ["int64Value": "17"]], ["value": ["int64Value": "3"]]]]]])
        precondition(google["gemini"] == 20)
        precondition(!AdditionalUsageClient.validScope("../other?key=secret"))
        for provider in ["claude", "zai", "minimax", "cost"] {
            do {
                switch provider {
                case "claude": _ = try AdditionalUsageClient.parseClaude([:])
                case "zai": _ = try AdditionalUsageClient.parseZAI([:])
                case "minimax": _ = try AdditionalUsageClient.parseMiniMax([:])
                default: _ = try AdditionalUsageClient.costAmounts([:])
                }
                fatalError("Missing provider data accepted")
            } catch {}
        }
        let cacheDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        let tokenCache = AntigravityTokenCache(directory: cacheDirectory), cacheNow = Date()
        try tokenCache.save(access: "fixture-access", source: "fixture-refresh", expiresIn: 3600, now: cacheNow)
        precondition(tokenCache.load(source: "fixture-refresh", now: cacheNow) == "fixture-access")
        precondition(tokenCache.load(source: "another-account", now: cacheNow) == nil)
        precondition(tokenCache.load(source: "fixture-refresh", now: cacheNow.addingTimeInterval(3550)) == nil)
        try tokenCache.save(access: "renewed-access", source: "fixture-refresh", expiresIn: 3600, now: cacheNow)
        precondition(tokenCache.load(source: "fixture-refresh", now: cacheNow) == "renewed-access")
        let permissions = try FileManager.default.attributesOfItem(atPath: cacheDirectory.appendingPathComponent("access.json").path)
        precondition((permissions[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        print("PASS: provider schema, currency isolation, remaining quotas, Google DELTA metrics, source-bound expiring token cache and private permissions")
        let session = UsageCredentialSession()
        let firstCredential = try await session.read("cached") { "fixture" }
        let secondCredential = try await session.read("cached") { fatalError("Reread Keychain during polling") }
        precondition(firstCredential == secondCredential)
        do { _ = try await session.read("denied") { throw UsageFailure.unavailable("denied") } } catch {}
        do { _ = try await session.read("denied") { fatalError("Retried denied authorization") } } catch {}
        await session.set("denied", value: "reconnected")
        let reconnected = try await session.read("denied") { fatalError("Ignored reconnected credential") }
        precondition(reconnected == "reconnected")
        await session.set("cached", value: nil)
        let disconnected = try await session.read("cached") { fatalError("Reloaded disconnected credential") }
        precondition(disconnected == nil)
        do {
            try UsageKeychainInteraction.run {
                var interaction: DarwinBoolean = true
                precondition(SecKeychainGetUserInteractionAllowed(&interaction) == errSecSuccess && !interaction.boolValue)
                throw UsageFailure.unavailable("test")
            }
        } catch {}
        print("PASS: credential caching, denied-read suppression, reconnect, disconnect, and legacy Keychain no-UI scope")
        do {
            let _: Int = try await UsageCredentialReader.read("test-stalled-keychain", timeout: 0.01) {
                Thread.sleep(forTimeInterval: 0.1)
                return 42
            }
            fatalError("Stalled Keychain did not time out")
        } catch {}
        do {
            let _: Int = try await UsageCredentialReader.read("test-stalled-keychain") { fatalError("Started duplicate blocked read") }
            fatalError("Accepted duplicate read")
        } catch {}
        try await Task.sleep(for: .milliseconds(150))
        let recovered = try await UsageCredentialReader.read("test-stalled-keychain") { 7 }
        precondition(recovered == 7)
        print("PASS: stalled credential reads time out, do not duplicate, and recover without double-resuming")
    }
}
