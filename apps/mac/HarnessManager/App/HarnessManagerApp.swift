import SwiftUI

@main
struct HarnessManagerApp: App {
    @State private var settingsStore: SettingsStore
    @State private var appState: AppState

    init() {
        let store = SettingsStore(inMemory: MarketingCapture.isActive)
        let state = AppState(settingsStore: store)
        if MarketingCapture.isActive { MarketingCapture.prepare(state) }
        _settingsStore = State(initialValue: store)
        _appState = State(initialValue: state)
    }

    var body: some Scene {
        // Intentionally minimal Scene graph.
        // Extra scenes (MenuBarExtra / CommandMenu observing @Observable state)
        // caused an infinite main-menu invalidation loop (100% CPU / beach ball).
        WindowGroup("Harness Manager", id: "main") {
            RootView()
                .environment(appState)
                .environment(settingsStore)
                .preferredColorScheme(MarketingCapture.isActive ? .light : nil)
                .frame(minWidth: 980, minHeight: 640)
                .task {
                    if let path = MarketingCapture.output { await MarketingCapture.export(appState, to: path) }
                    else if let path = MarketingCapture.recordingOutput { await MarketingCapture.recordDiscover(appState, to: path) }
                    else { appState.start() }
                }
        }
        .defaultSize(width: 1100, height: 720)
    }
}


/// AppKit owns this static menu, avoiding SwiftUI scene observation/invalidation loops.
@MainActor
final class HarnessStatusItem: NSObject {
    static let shared = HarnessStatusItem()
    private var item: NSStatusItem?
    private var openDashboard: (() -> Void)?

    func configure(visible: Bool, openDashboard: @escaping () -> Void) {
        self.openDashboard = openDashboard
        guard visible else {
            if let item { NSStatusBar.system.removeStatusItem(item) }
            item = nil
            return
        }
        guard item == nil else { return }
        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let mark = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            let path = NSBezierPath()
            path.lineWidth = 2.2
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: NSPoint(x: 3, y: 16))
            path.line(to: NSPoint(x: 6, y: 16))
            path.line(to: NSPoint(x: 6, y: 2))
            path.line(to: NSPoint(x: 3, y: 2))
            path.move(to: NSPoint(x: 15, y: 16))
            path.line(to: NSPoint(x: 12, y: 16))
            path.line(to: NSPoint(x: 12, y: 2))
            path.line(to: NSPoint(x: 15, y: 2))
            path.move(to: NSPoint(x: 6, y: 9))
            path.line(to: NSPoint(x: 12, y: 9))
            path.stroke()
            return true
        }
        mark.isTemplate = true
        status.button?.image = mark
        status.button?.toolTip = "Harness Manager"
        status.button?.setAccessibilityLabel("Harness Manager")
        let menu = NSMenu()
        let open = NSMenuItem(title: "Open Harness Manager", action: #selector(showDashboard), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Harness Manager", action: #selector(quitApp), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
        status.menu = menu
        item = status
    }

    @objc private func showDashboard() {
        openDashboard?()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() { NSApp.terminate(nil) }
}

/// Marketing exports render the same SwiftUI hierarchy as the shipping app.
/// Isolated fixtures prevent scanning, running commands, or persisting user preferences.
@MainActor
enum MarketingCapture {
    static var output: String? {
        guard let i = CommandLine.arguments.firstIndex(of: "--capture-marketing"), CommandLine.arguments.indices.contains(i + 1) else { return nil }
        return CommandLine.arguments[i + 1]
    }
    static var recordingOutput: String? {
        guard let i = CommandLine.arguments.firstIndex(of: "--record-discover"), CommandLine.arguments.indices.contains(i + 1) else { return nil }
        return CommandLine.arguments[i + 1]
    }
    static var isActive: Bool { output != nil || recordingOutput != nil }
    static var didExport = false
    static let benchmarks = BenchmarkStore(inMemory: true)
    static let news: [HarnessArticle] = [
        HarnessNewsService.article(source: HarnessNewsService.sources[1], title: "The Anatomy of Harness Engineering: How to Evaluate, Iterate, and Guard AI Coding Agents", url: URL(string: "https://developers.googleblog.com/the-anatomy-of-harness-engineering-how-to-evaluate-iterate-and-guard-ai-coding-agents/")!, date: nil, summary: "A guide to evaluating the actions of coding agents, iterating on prompts, and catching regressions with behavioral tests."),
        HarnessNewsService.article(source: HarnessNewsService.sources[0], title: "Introducing the Agents API", url: URL(string: "https://openai.com/index/introducing-the-agents-api")!, date: HarnessNewsService.parseDate("2026-09-10T00:00:00Z"), summary: "Read the product announcement from OpenAI."),
        HarnessNewsService.article(source: HarnessNewsService.sources[0], title: "Introducing the Admin plugin for ChatGPT Work and Codex", url: URL(string: "https://openai.com/index/introducing-admin-plugin")!, date: HarnessNewsService.parseDate("2026-08-25T00:00:00Z"), summary: "A new announcement from the team behind Codex. Open the source for the full story.")
    ]

    static func prepare(_ state: AppState) {
        state.isMarketingCapture = true
        state.settingsStore.settings.hasCompletedOnboarding = true
        state.settingsStore.settings.showMenuBarExtra = false
        state.harnesses = AppState.placeholderHarnesses().filter { ["claude-code", "codex", "gemini-cli", "cursor", "opencode", "warp", "antigravity", "antigravity-ide", "t3-code", "conductor", "superset", "orca", "herdr"].contains($0.id) }
        for i in state.harnesses.indices {
            let id = state.harnesses[i].id
            let installed = ["claude-code", "codex", "cursor", "warp"].contains(id)
            state.harnesses[i].isInstalled = installed
            state.harnesses[i].status = id == "codex" ? .running : installed ? .installed : .unavailable
            state.harnesses[i].installedVersion = installed ? (id == "claude-code" ? "2.1.152" : id == "codex" ? "0.155.0" : id == "cursor" ? "3.21.13" : "0.2026.09") : nil
            state.harnesses[i].updateStatus = id == "claude-code" ? .updateAvailable : installed ? .current : .notApplicable
            state.harnesses[i].latestVersion = id == "claude-code" ? "2.1.153" : nil
            state.harnesses[i].installSource = ["cursor", "warp"].contains(id) ? .macApplication : installed ? .npm : .unknown
        }
        state.packageManagers = [.init(id: "npm", name: "npm", isInstalled: true, path: "/usr/local/bin/npm", version: "11.0"), .init(id: "homebrew", name: "Homebrew", isInstalled: true, path: "/opt/homebrew/bin/brew", version: "4.0")]
        state.providers = ProviderCatalog.all.map { .init(id: $0.id, name: $0.name, isConfigured: ["openai", "anthropic", "google"].contains($0.id), detectedSignals: ["openai", "anthropic", "google"].contains($0.id) ? ["Local configuration found"] : [], harnessIds: []) }
        state.processes = [.init(id: 48201, pid: 48201, executableName: "codex", harnessId: "codex", harnessName: "Codex CLI", cpuPercent: 2, memoryBytes: 146_800_640, runtimeSeconds: 840, workingDirectory: "~/Developer/website", projectName: "website")]
    }

    static func export(_ state: AppState, to path: String) async {
        guard !didExport else { return }; didExport = true
        do {
            let folder = URL(fileURLWithPath: path, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            // Fetch the real rankings before rendering; never export a loading or error screen.
            for id in ["smartest", "coding", "design"] {
                guard let collection = RankingCollection.catalog.first(where: { $0.id == id }) else { throw CocoaError(.coderInvalidValue) }
                await benchmarks.refresh(collection, force: true)
                guard let snapshot = benchmarks.rankingSnapshots[id], !snapshot.entries.isEmpty,
                      benchmarks.errors["ranking-\(id)"] == nil else {
                    throw NSError(domain: "MarketingCapture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not load live \(id) rankings. Existing marketing images have not been replaced."])
                }
            }
            try await Task.sleep(for: .milliseconds(700))
            guard let window = NSApp.windows.first(where: { $0.contentView != nil && $0.isVisible }) else { throw CocoaError(.fileWriteUnknown) }
            window.appearance = NSAppearance(named: .aqua)
            window.setContentSize(NSSize(width: 1200, height: 800))
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            let captures: [(String, SidebarItem, HarnessFilter, DiscoverCategory, String?)] = [
                ("workspace", .allHarnesses, .all, .harnesses, nil),
                ("discover", .store, .all, .harnesses, nil),
                ("discover-harnesses-more", .store, .all, .harnesses, "meta-harnesses"),
                ("discover-mcps", .store, .all, .mcps, nil),
                ("discover-mcps-more", .store, .all, .mcps, "microsoft/playwright-mcp"),
                ("discover-skills", .store, .all, .skills, nil),
                ("discover-skills-more", .store, .all, .skills, "composiohq/awesome-claude-skills"),
                ("updates", .allHarnesses, .updateAvailable, .harnesses, nil),
                ("providers", .providers, .all, .harnesses, nil),
                ("processes", .processes, .all, .harnesses, nil),
                ("news", .news, .all, .harnesses, nil),
                ("benchmarks", .benchmarks, .all, .harnesses, nil),
                ("rankings-coding", .benchmarks, .all, .harnesses, nil),
                ("rankings-design", .benchmarks, .all, .harnesses, nil)
            ]
            for (name, page, filter, discoverCategory, scrollTarget) in captures {
                state.marketingRankingID = name == "rankings-coding" ? "coding" : name == "rankings-design" ? "design" : "smartest"
                state.marketingDiscoverScrollTarget = nil
                state.marketingDiscoverCategory = discoverCategory
                state.selectedSidebar = page; state.harnessFilter = filter
                try await Task.sleep(for: .milliseconds(180))
                state.marketingDiscoverScrollTarget = scrollTarget
                try await Task.sleep(for: .milliseconds(420))
                let destination = folder.appendingPathComponent("\(name).png")
                let capture = Process()
                capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                capture.arguments = ["-x", "-o", "-l", String(window.windowNumber), destination.path]
                try capture.run()
                capture.waitUntilExit()
                guard capture.terminationStatus == 0, FileManager.default.fileExists(atPath: destination.path) else { throw CocoaError(.fileWriteUnknown) }

            }
            print("Exported \(captures.count) native SwiftUI screenshots to \(path)")
            NSApp.terminate(nil)
        } catch { fputs("Screenshot export failed: \(error)\n", stderr); exit(1) }
    }

    static func recordDiscover(_ state: AppState, to path: String) async {
        guard !didExport else { return }; didExport = true
        do {
            let destination = URL(fileURLWithPath: path)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try await Task.sleep(for: .milliseconds(700))
            guard let window = NSApp.windows.first(where: { $0.contentView != nil && $0.isVisible }) else { throw CocoaError(.fileWriteUnknown) }
            window.appearance = NSAppearance(named: .aqua)
            window.setContentSize(NSSize(width: 1200, height: 800))
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            state.marketingDiscoverCategory = .harnesses
            state.marketingDiscoverScrollTarget = nil
            state.marketingDiscoverScrollDuration = nil
            state.selectedSidebar = .store
            try await Task.sleep(for: .milliseconds(700))

            let recording = Process()
            recording.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            recording.arguments = ["-v", "-x", "-o", "-l", String(window.windowNumber), "-V", "14", destination.path]
            NSCursor.hide()
            defer { NSCursor.unhide() }
            try recording.run()

            // Video capture takes a moment to establish its stream. Keep the
            // initial harness grid visible before beginning the first scroll.
            try await Task.sleep(for: .milliseconds(2_200))
            state.marketingDiscoverScrollDuration = 2.0
            state.marketingDiscoverScrollTarget = "meta-harnesses"
            try await Task.sleep(for: .milliseconds(2_400))

            state.marketingDiscoverScrollTarget = nil
            state.marketingDiscoverScrollDuration = nil
            state.marketingDiscoverCategory = .mcps
            try await Task.sleep(for: .milliseconds(850))
            state.marketingDiscoverScrollDuration = 1.8
            state.marketingDiscoverScrollTarget = "microsoft/playwright-mcp"
            try await Task.sleep(for: .milliseconds(2_100))

            state.marketingDiscoverScrollTarget = nil
            state.marketingDiscoverScrollDuration = nil
            state.marketingDiscoverCategory = .skills
            try await Task.sleep(for: .milliseconds(850))
            state.marketingDiscoverScrollDuration = 1.8
            state.marketingDiscoverScrollTarget = "composiohq/awesome-claude-skills"
            try await Task.sleep(for: .milliseconds(2_100))

            while recording.isRunning { try await Task.sleep(for: .milliseconds(200)) }
            guard recording.terminationStatus == 0, FileManager.default.fileExists(atPath: destination.path) else { throw CocoaError(.fileWriteUnknown) }
            print("Recorded native Discover walkthrough to \(destination.path)")
            NSApp.terminate(nil)
        } catch { fputs("Discover recording failed: \(error)\n", stderr); exit(1) }
    }
}
