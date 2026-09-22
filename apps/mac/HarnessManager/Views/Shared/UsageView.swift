import SwiftUI

struct UsageView: View {
    @State private var store = UsageStore.shared
    @State private var showingConnection = false
    @State private var showingBalanceConnection = false
    @State private var additionalConnection: UsageProvider?
    @State private var showingSettings = false
    @State private var connectionError: String?
    private let accent = Color(red: 0.82, green: 0.34, blue: 0.16)
    private var dashboardProviders: [UsageProvider] {
        UsageProvider.allCases.filter { !$0.live && store.preferences.enabled($0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .top, spacing: 20) {
                    PageHeading(eyebrow: "YOUR AI STACK", title: "Room to keep going.", subtitle: "Usage, remaining limits, and reset times. Straight from your accounts.")
                    Button { showingSettings = true } label: { Label("Customize", systemImage: "slider.horizontal.3") }.controlSize(.large)
                    Button { Task { await store.refresh(force: true) } } label: {
                        Label(store.loading ? "Refreshing…" : "Refresh", systemImage: "arrow.clockwise")
                    }.disabled(store.loading).controlSize(.large)
                }
                if store.preferences.enabled(.cursor) { desktopCard("Cursor", logo: "Logo-cursor", snapshot: store.cursor, error: store.cursorError, isLoading: store.cursorLoading, dashboard: "https://cursor.com/dashboard") }
                if store.preferences.enabled(.antigravity) { desktopCard("Antigravity", logo: "Logo-antigravity", snapshot: store.antigravity, error: store.antigravityError, isLoading: store.antigravityLoading, dashboard: "https://antigravity.google/") }
                if store.preferences.enabled(.codex) { codexCard }

                if store.preferences.enabled(.openrouter) { routerCard }
                ForEach(AdditionalUsageClient.providers.filter { store.preferences.enabled($0) }) { provider in
                    additionalCard(provider)
                }

                if !UsageProvider.allCases.contains(where: { $0.live && store.preferences.enabled($0) }) {
                    ContentUnavailableView("Usage connections are off", systemImage: "slider.horizontal.3", description: Text("Open Customize to turn on the accounts you want to track."))
                }
                if !dashboardProviders.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Console-only provider").font(.system(size: 19, weight: .semibold))
                    Text("Groq does not publish an account-wide usage endpoint in its public API reference. Its console remains the source for totals and spend limits.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    VStack(spacing: 0) {
                        ForEach(dashboardProviders) { provider in
                            if let url = Self.dashboardURLs[provider.id] {
                                if provider != dashboardProviders.first { Divider().padding(.leading, 58) }
                                dashboardRow(provider.name, detail: "Account usage API unavailable", url: url, logo: provider.logo)
                            }
                        }
                    }.usageSurface()
                }
                }
                Label("Refreshes every 5 minutes while this page is open. Subscription percentages and API dollars stay separate.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(28).frame(maxWidth: 1100).frame(maxWidth: .infinity)
        }
        .navigationTitle("Usage")
        .task {
            await store.refresh()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(300)) } catch { return }
                await store.refresh()
            }
        }
        .sheet(isPresented: $showingConnection) { RouterUsageConnection(store: store) }
        .sheet(isPresented: $showingBalanceConnection) { RouterUsageConnection(store: store, balanceOnly: true) }
        .sheet(item: $additionalConnection) { provider in AdditionalUsageConnection(provider: provider, store: store) }
        .sheet(isPresented: $showingSettings) { UsageSettingsView(store: store) }
        .alert("Connection unavailable", isPresented: Binding(get: { connectionError != nil }, set: { if !$0 { connectionError = nil } })) {
            Button("OK") { connectionError = nil }
        } message: { Text(connectionError ?? "") }
    }

    private var codexCard: some View {
                VStack(alignment: .leading, spacing: 0) {
                    sourceHeader(name: "Codex", subtitle: "ChatGPT subscription · existing Codex sign-in", logo: "Logo-codex", connected: store.codex != nil, loading: store.codexLoading)
                    Divider()
                    VStack(alignment: .leading, spacing: 22) {
                        if let usage = store.codex {
                            if usage.windows.isEmpty {
                                notice("This account didn’t return any subscription limits. No quota is assumed.")
                            }
                            ForEach(usage.windows) { window in quota(window) }
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(usage.lifetimeTokens.map { $0.formatted(.number.notation(.compactName)) } ?? "—")
                                    .font(.system(size: 28, weight: .semibold, design: .rounded)).monospacedDigit()
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Lifetime tokens").font(.system(size: 12, weight: .medium))
                                    Text(usage.tokenMessage ?? "Account total reported by Codex; separate from subscription limits.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            freshness(usage.fetchedAt, stale: store.codexError != nil)
                        } else if store.codexLoading {
                            loading("Reading your Codex account…")
                        }
                        if let error = store.codexError { notice(error) }
                    }.padding(22)
                }.usageSurface()
    }

    private var routerCard: some View {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        sourceHeader(name: "OpenRouter", subtitle: "Account credits & key spending", logo: nil, connected: store.routerConnected || store.creditsConnected, loading: store.routerLoading || store.creditsLoading)
                        Spacer(minLength: 0)
                        if store.routerConnected || store.creditsConnected {
                            Menu {
                                Button("Connect account balance") { showingBalanceConnection = true }
                                if store.creditsConnected { Button("Disconnect balance key", role: .destructive) {
                                    Task { do { try await store.disconnectCredits() } catch { connectionError = error.localizedDescription } }
                                } }
                                Button("Replace API key") { showingConnection = true }
                                Button("Disconnect", role: .destructive) {
                                    Task { do { try await store.disconnectRouter() } catch { connectionError = error.localizedDescription } }
                                }
                            } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton)
                                .frame(width: 26).padding(.trailing, 22).disabled(store.loading)
                        }
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 20) {
                        routerBalance
                        Divider()
                        Text("CONNECTED KEY").font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundStyle(.secondary)
                        if let usage = store.router {
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 36) { routerMetrics(usage) }
                                VStack(alignment: .leading, spacing: 18) { routerMetrics(usage) }
                            }
                            if let limit = usage.limit, limit > 0, let remaining = usage.limitRemaining {
                                ProgressView(value: min(1, max(0, 1 - remaining / limit))).tint(accent)
                                Text("\(money(limit)) key budget · \(usage.limitReset.map { "resets \($0)" } ?? "no recurring reset")")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text(usage.limit == nil ? "No budget cap on this key. Account credits are shown separately above." : "Remaining key budget isn’t reported.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if let date = store.routerFetchedAt { freshness(date, stale: store.routerError != nil) }
                        } else if store.routerLoading {
                            loading("Fetching your key’s spending…")
                        } else if !store.routerConnected {
                            HStack(alignment: .center, spacing: 24) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Keep your API budget in view.").font(.system(size: 17, weight: .semibold))
                                    Text("Connect a key to see spending and its remaining budget. Your key is saved in macOS Keychain and sent only to OpenRouter.")
                                        .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                                Button("Connect OpenRouter") { showingConnection = true }.buttonStyle(.borderedProminent).controlSize(.large)
                            }
                        }
                        if let error = store.routerError { notice(error) }
                    }.padding(22)
                }.usageSurface()
    }

    private var routerBalance: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ACCOUNT CREDITS LEFT").font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundStyle(.secondary)
                    Text(store.routerCredits.map { money($0.balance) } ?? "—")
                        .font(.system(size: 38, weight: .semibold, design: .rounded)).monospacedDigit()
                }
                Spacer()
                if store.creditsLoading { ProgressView().controlSize(.small) }
                Button(store.creditsConnected ? "Replace balance key" : "Connect balance") { showingBalanceConnection = true }
                    .disabled(store.loading)
            }
            if let credits = store.routerCredits {
                Text("\(money(credits.totalCredits)) total credits · \(money(credits.totalUsage)) account lifetime spend")
                    .font(.caption).foregroundStyle(.secondary)
                if let date = store.creditsFetchedAt { freshness(date, stale: store.creditsError != nil) }
            } else {
                Text("Full account balance, separate from an individual key’s spending cap.").font(.caption).foregroundStyle(.secondary)
            }
            if let error = store.creditsError { notice(error) }
        }
    }

    private func sourceHeader(name: String, subtitle: String, logo: String?, connected: Bool, loading: Bool) -> some View {
        HStack(spacing: 12) {
            logoView(logo)
            VStack(alignment: .leading, spacing: 5) {
                Text(name).font(.system(size: 17, weight: .semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if loading { ProgressView().controlSize(.small).accessibilityLabel("Refreshing \(name)") }
            else { Text(connected ? "Connected" : "Not connected").font(.caption.weight(.medium)).foregroundStyle(connected ? Color.green : .secondary) }
        }.padding(22)
    }

    private func additionalCard(_ provider: UsageProvider) -> some View {
        let snapshot = store.additionalSnapshots[provider]
        let busy = store.additionalLoading.contains(provider)
        return VStack(alignment: .leading, spacing: 16) {
            sourceHeader(name: provider.name, subtitle: snapshot?.source ?? "Connect to view account usage", logo: provider.logo, connected: snapshot != nil, loading: busy)
            VStack(alignment: .leading, spacing: 16) {
                if let snapshot {
                    ForEach(snapshot.metrics) { metric in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(metric.title).font(.subheadline.weight(.medium))
                                Spacer()
                                Text(metric.formatted(metric.remaining ?? metric.used)).font(.title2.weight(.semibold)).monospacedDigit()
                                Text(metric.valueLabel ?? (metric.remaining == nil ? "used" : "remaining")).font(.caption).foregroundStyle(.secondary)
                            }
                            if let cap = metric.limit, cap > 0 { ProgressView(value: min(metric.used, cap), total: cap).tint(accent) }
                            if let reset = metric.resetsAt { Text("Resets \(reset.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    if let note = snapshot.note { Text(note).font(.caption).foregroundStyle(.secondary) }
                    freshness(snapshot.fetchedAt, stale: false)
                } else { Text(AdditionalUsageClient.requirements(provider)).font(.subheadline).foregroundStyle(.secondary) }
                if let error = store.additionalErrors[provider] { notice(error) }
                HStack {
                    Button(provider == .anthropic ? "Connect Claude Code" : (snapshot == nil ? "Connect \(provider.name)" : "Update connection")) {
                        if provider == .anthropic { Task { await store.connectClaude() } }
                        else { additionalConnection = provider }
                    }.disabled(busy)
                    Spacer()
                    if let url = Self.dashboardURLs[provider.id], let destination = URL(string: url) { Link("Dashboard ↗", destination: destination).font(.caption) }
                }
            }.padding([.horizontal, .bottom], 22)
        }.usageSurface()
    }

    private func desktopCard(_ name: String, logo: String, snapshot: DesktopUsageSnapshot?, error: String?, isLoading: Bool, dashboard: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sourceHeader(name: name, subtitle: snapshot?.source ?? "Uses your existing app sign-in · no API key needed", logo: logo, connected: snapshot != nil, loading: isLoading)
            Divider()
            VStack(alignment: .leading, spacing: 20) {
                if let snapshot {
                    ForEach(snapshot.metrics) { metric in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(metric.title).font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Text(metric.formatted(metric.remaining ?? metric.used)).font(.system(size: 26, weight: .semibold, design: .rounded)).monospacedDigit()
                                Text(metric.remaining == nil ? "used" : "remaining").font(.caption).foregroundStyle(.secondary)
                            }
                            if let limit = metric.limit, limit > 0 {
                                ProgressView(value: min(metric.used, limit), total: limit).tint(accent)
                                    .accessibilityLabel("\(metric.title), \(metric.formatted(metric.used)) of \(metric.formatted(limit)) used")
                            }
                            HStack {
                                Text("\(metric.formatted(metric.used)) used\(metric.limit.map { " of \(metric.formatted($0))" } ?? "")")
                                Spacer()
                                if let reset = metric.resetsAt {
                                    Text(reset < Date() ? "Reset passed · refresh for current limits" : "Resets \(reset.formatted(date: .abbreviated, time: .shortened))")
                                }
                            }.font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if snapshot.metrics.isEmpty { notice("The account returned no available quota values. Missing data isn’t treated as zero usage.") }
                    if let note = snapshot.note { Text(note).font(.caption).foregroundStyle(.secondary) }
                    freshness(snapshot.fetchedAt, stale: false)
                } else if isLoading { loading("Reading your \(name) usage…") }
                if let error { notice(error) }
                if name == "Antigravity" {
                    Button("Reconnect Antigravity") { Task { await store.reconnectAntigravity() } }
                        .disabled(isLoading)
                        .help("Read your saved Antigravity sign-in. macOS may ask for Keychain access once.")
                }
                HStack {
                    Text("Uses the app’s undocumented usage service.").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Link(name == "Antigravity" ? "Antigravity ↗" : "Dashboard ↗", destination: URL(string: dashboard)!).font(.caption)
                }
            }.padding(22)
        }.usageSurface()
    }

    private func quota(_ window: UsageWindow) -> some View {
        let expired = window.resetsAt.map { $0 <= Date() } ?? false
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(window.duration).font(.system(size: 14, weight: .semibold))
                    Text(window.name).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(window.remaining))%").font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
                Text("remaining").font(.caption).foregroundStyle(.secondary)
            }
            ProgressView(value: window.usedPercent, total: 100).tint(window.remaining <= 10 ? .red : accent)
                .accessibilityLabel("\(window.name), \(window.duration), \(Int(window.usedPercent)) percent used")
            HStack {
                Text("\(Int(window.usedPercent))% used")
                Spacer()
                if let reset = window.resetsAt {
                    if expired { Text("Reset passed · refresh for current limits") }
                    else { Text("Resets \(reset.formatted(date: .abbreviated, time: .shortened))") }
                } else { Text("Reset time unavailable") }
            }.font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func routerMetrics(_ usage: RouterUsage) -> some View {
        metric("Key spend today", value: usage.usageDaily)
        metric("Key spend this month", value: usage.usageMonthly)
        metric("Key lifetime spend", value: usage.usage)
        metric("Key budget left", value: usage.limitRemaining)
    }
    private func metric(_ label: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value.map(money) ?? "—").font(.system(size: 24, weight: .semibold, design: .rounded)).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func money(_ value: Double) -> String { value.formatted(.currency(code: "USD")) }
    private func freshness(_ date: Date, stale: Bool) -> some View {
        Label("\(stale ? "Last successful update" : "Updated") \(date.formatted(date: .abbreviated, time: .shortened))", systemImage: stale ? "clock.badge.exclamationmark" : "checkmark.circle")
            .font(.caption).foregroundStyle(.secondary)
    }
    private func notice(_ message: String) -> some View {
        Label(message, systemImage: "info.circle").font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
    private func loading(_ text: String) -> some View {
        HStack(spacing: 12) { ProgressView().controlSize(.small); Text(text).foregroundStyle(.secondary) }.frame(height: 64)
    }
    @ViewBuilder private func logoView(_ logo: String?) -> some View {
        if let logo { Image(logo).resizable().scaledToFit().frame(width: 30, height: 30) }
        else { Image(systemName: "network").font(.system(size: 23)).frame(width: 30, height: 30).foregroundStyle(.secondary) }
    }
    private func dashboardRow(_ name: String, detail: String, url: String, logo: String?) -> some View {
        HStack(spacing: 14) {
            logoView(logo)
            Text(name).font(.system(size: 13, weight: .semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Link(destination: URL(string: url)!) { Label("Dashboard", systemImage: "arrow.up.right") }.font(.caption)
        }.padding(16)
    }
    private static let dashboardURLs = [
        "anthropic": "https://claude.ai/settings/usage",
        "openai": "https://platform.openai.com/usage", "google": "https://aistudio.google.com/",
        "groq": "https://console.groq.com/", "xai": "https://console.x.ai/",
        "mistral": "https://console.mistral.ai/", "zai": "https://open.bigmodel.cn/", "minimax": "https://platform.minimax.io/"
    ]
}

private struct RouterUsageConnection: View {
    @Environment(\.dismiss) private var dismiss
    let store: UsageStore
    var balanceOnly = false
    @State private var key = ""
    @State private var saving = false
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(balanceOnly ? "Connect account balance" : "Connect OpenRouter").font(.title2.weight(.semibold))
            Text(balanceOnly ? "Use an OpenRouter management key to read full account credits. It is saved separately from your usage key, so your key budget remains connected." : "Use the API key you run your tools with. This connects key spending and budget. Account balance may require a separate management key.").foregroundStyle(.secondary)
            SecureField(balanceOnly ? "OpenRouter management key" : "OpenRouter API key", text: $key).textFieldStyle(.roundedBorder)
            Text("Stored in macOS Keychain. Sent only to openrouter.ai to read usage; no model requests are made.").font(.caption).foregroundStyle(.secondary)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Link("Find your API key ↗", destination: URL(string: "https://openrouter.ai/settings/keys")!)
                Spacer()
                Button("Cancel") { key = ""; dismiss() }.disabled(saving)
                Button(saving ? "Connecting…" : "Connect") {
                    saving = true; error = nil
                    Task {
                        do {
                            if balanceOnly { try await store.connectCredits(key) } else { try await store.connectRouter(key) }
                            key = ""; dismiss()
                        }
                        catch { self.error = (error as? UsageFailure)?.errorDescription ?? "Couldn’t connect. Check your network and API key." }
                        saving = false
                    }
                }.buttonStyle(.borderedProminent).disabled(saving || key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(28).frame(width: 460).interactiveDismissDisabled(saving)
    }
}

private extension View {
    func usageSurface() -> some View {
        background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.07)))
    }
}

private struct UsageSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let store: UsageStore
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Customize Usage").font(.title2.weight(.semibold))
                    Text("Choose what belongs in your overview.").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            Text("Turning a connection off hides its card and stops its usage checks. Saved sign-ins stay connected for when you turn it back on.")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    settingsGroup("LIVE CONNECTIONS", providers: UsageProvider.allCases.filter(\.live))
                    settingsGroup("DASHBOARD SHORTCUTS", providers: UsageProvider.allCases.filter { !$0.live })
                }
            }
            Text("Dashboard shortcuts don’t fetch usage. No sample balances or simulated connections are shown.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(26).frame(width: 510, height: 630)
    }
    private func settingsGroup(_ title: String, providers: [UsageProvider]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(providers) { provider in
                    HStack(spacing: 14) {
                        if let logo = provider.logo { Image(logo).resizable().scaledToFit().frame(width: 30, height: 30) }
                        else { Image(systemName: "network").font(.title2).frame(width: 30, height: 30) }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(provider.name).font(.system(size: 14, weight: .semibold))
                            Text(provider.live ? "Live provider data · connection required" : "Console only · no public usage endpoint")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle(provider.name, isOn: Binding(get: { store.preferences.enabled(provider) }, set: { store.setEnabled(provider, $0) }))
                            .toggleStyle(.switch).labelsHidden()
                    }.padding(14)
                    if provider != providers.last { Divider().padding(.leading, 58) }
                }
            }.usageSurface()
        }
    }
}

private struct AdditionalUsageConnection: View {
    let provider: UsageProvider
    let store: UsageStore
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var scope = ""
    @State private var error: String?
    @State private var busy = false
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Connect \(provider.name)").font(.title2.weight(.semibold))
            Text(AdditionalUsageClient.requirements(provider)).foregroundStyle(.secondary)
            if provider == .google || provider == .xai {
                TextField(provider == .google ? "Google Cloud project ID" : "xAI team ID", text: $scope).textFieldStyle(.roundedBorder)
            }
            SecureField(provider == .google ? "Google Cloud OAuth access token" : "API key", text: $key).textFieldStyle(.roundedBorder)
            Text("Saved in macOS Keychain. Sent only to this provider’s usage API. No model requests are made.").font(.caption).foregroundStyle(.secondary)
            if provider == .google { Text("An OAuth access token expires. Until Google sign-in is added, replace it here when access expires.").font(.caption).foregroundStyle(.secondary) }
            if let error { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
            HStack {
                Button("Cancel") { dismiss() }.disabled(busy)
                Spacer()
                if busy { ProgressView().controlSize(.small) }
                Button("Connect") {
                    busy = true; error = nil
                    Task {
                        do { try await store.connectAdditional(provider, key: key, scope: scope); key = ""; dismiss() }
                        catch { self.error = (error as? UsageFailure)?.errorDescription ?? "Connection failed. Check your credential and permissions." }
                        busy = false
                    }
                }.disabled(busy || key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).keyboardShortcut(.defaultAction)
            }
        }.padding(28).frame(width: 500)
    }
}
