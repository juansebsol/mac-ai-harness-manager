import AppKit
import Foundation
import OSLog
import Observation
import SwiftUI

enum SidebarItem: String, Hashable, CaseIterable, Identifiable {
    case allHarnesses, running, problems, store, news, benchmarks
    case usage, providers, mcpServers, skills
    case processes
    case settings, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allHarnesses: return "Workspace"
        case .running: return "Running"
        case .problems: return "Problems"
        case .store: return "Discover"
        case .news: return "Harness news"
        case .benchmarks: return "Benchmarks"
        case .usage: return "Usage"
        case .providers: return "Providers"
        case .mcpServers: return "MCP Servers"
        case .skills: return "Skills"
        case .processes: return "Processes"
        case .settings: return "Settings"
        case .about: return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .allHarnesses: return "square.grid.2x2"
        case .running: return "play.circle"
        case .problems: return "exclamationmark.triangle"
        case .store: return "bag"
        case .news: return "newspaper"
        case .benchmarks: return "chart.bar.xaxis"
        case .usage: return "gauge.with.dots.needle.50percent"
        case .providers: return "key"
        case .mcpServers: return "server.rack"
        case .skills: return "books.vertical"
        case .processes: return "cpu"
        case .settings: return "gearshape"
        case .about: return "info.circle"
        }
    }

    static let harnesses: [SidebarItem] = [.allHarnesses, .running, .problems, .store, .news, .benchmarks]
    static let infrastructure: [SidebarItem] = [.usage, .providers, .mcpServers, .skills]
    static let system: [SidebarItem] = [.processes]
    static let bottom: [SidebarItem] = [.settings, .about]
}

enum HarnessFilter: String, CaseIterable, Identifiable {
    case all, installed, running, updateAvailable, misconfigured, notInstalled
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "All"
        case .installed: return "Installed"
        case .running: return "Running"
        case .updateAvailable: return "Update Available"
        case .misconfigured: return "Misconfigured"
        case .notInstalled: return "Not Installed"
        }
    }
}

@Observable
@MainActor
final class AppState {
    var selectedSidebar: SidebarItem = .allHarnesses
    var selectedHarnessId: String?
    var harnesses: [HarnessSnapshot] = []
    var processes: [DetectedProcess] = []
    var projects: [CodingProject] = []
    var providers: [ProviderStatus] = []
    var mcpServers: [MCPServer] = []
    var skills: [SkillItem] = []
    var packageManagers: [PackageManagerInfo] = []

    var isScanning = false
    var isEnriching = false
    var isCheckingUpdates = false
    var scanMessage = "Scanning your Mac for AI developer tools…"
    var lastRefresh: Date?
    var isMarketingCapture = false
    var marketingRankingID = "smartest"
    var searchText = ""
    var harnessFilter: HarnessFilter = .all

    var actionError: String?
    var updateConfirmation: UpdateConfirmation?
    var executionSheet: ExecutionSheetState?
    var diagnosticsSheet: DiagnosticsSheetState?
    var launchSheet: LaunchSheetState?
    var projectPickerHarness: HarnessSnapshot?

    let settingsStore: SettingsStore
    private let logger = Logger(subsystem: "com.harnessmanager.app", category: "AppState")
    private var refreshTask: Task<Void, Never>?
    private var enrichTask: Task<Void, Never>?

    enum MutatingActionKind: String {
        case install
        case update
    }

    struct UpdateConfirmation: Identifiable {
        let id = UUID()
        let kind: MutatingActionKind
        let harnessId: String
        let harnessName: String
        let installed: String?
        let latest: String?
        let displayCommand: String
        let executable: URL
        let arguments: [String]

        var prerequisiteFormula: String? = nil

        var title: String {
            switch kind {
            case .install: return "Install \(harnessName)"
            case .update: return "Update \(harnessName)"
            }
        }

        var confirmLabel: String {
            if prerequisiteFormula != nil { return "Set up & Install" }
            switch kind {
            case .install: return "Install"
            case .update: return "Update"
            }
        }
    }

    struct ExecutionSheetState: Identifiable {
        let id = UUID()
        let title: String
        var output: String = ""
        var isRunning = true
        var exitCode: Int32?
    }

    struct DiagnosticsSheetState: Identifiable {
        let id = UUID()
        let harnessName: String
        var results: [DiagnosticResult] = []
        var isRunning = true
    }

    struct LaunchSheetState: Identifiable {
        let id = UUID()
        let project: CodingProject
    }

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        seedPlaceholderHarnessesIfNeeded()
        AppStateBridge.shared = self
    }

    var summary: HarnessSummary {
        HarnessSummary(
            installed: harnesses.filter(\.isInstalled).count,
            running: harnesses.filter { $0.status == .running }.count,
            updates: harnesses.filter { $0.updateStatus == .updateAvailable }.count,
            issues: harnesses.filter { $0.status == .misconfigured }.count
        )
    }

    var filteredHarnesses: [HarnessSnapshot] {
        var items = harnesses
        switch selectedSidebar {
        case .running: items = items.filter { $0.status == .running }
        case .problems: items = items.filter { $0.status == .misconfigured || ($0.definitionIncomplete && $0.isInstalled) }
        default: break
        }
        switch harnessFilter {
        case .all: break
        case .installed: items = items.filter(\.isInstalled)
        case .running: items = items.filter { $0.status == .running }
        case .updateAvailable: items = items.filter { $0.updateStatus == .updateAvailable }
        case .misconfigured: items = items.filter { $0.status == .misconfigured }
        case .notInstalled: items = items.filter { !$0.isInstalled }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            items = items.filter {
                $0.name.lowercased().contains(q)
                    || $0.displayProvider.lowercased().contains(q)
                    || ($0.installedVersion?.lowercased().contains(q) ?? false)
                    || $0.installSource.displayName.lowercased().contains(q)
            }
        }
        return items
    }

    var selectedHarness: HarnessSnapshot? {
        guard let selectedHarnessId else { return nil }
        return harnesses.first { $0.definitionId == selectedHarnessId }
    }

    /// Inspector card is open only while a harness is selected.
    var isInspectorPresented: Bool {
        selectedHarnessId != nil
            && [.allHarnesses, .running, .problems, .store].contains(selectedSidebar)
    }

    func openInspector(for harnessId: String) {
        selectedHarnessId = harnessId
    }

    func closeInspector() {
        selectedHarnessId = nil
    }

    var runningMenuItems: [(name: String, project: String)] {
        processes.compactMap { process in
            guard let name = process.harnessName else { return nil }
            return (name, process.projectName ?? "—")
        }
    }

    func start() {
        guard !isMarketingCapture else { return }
        seedPlaceholderHarnessesIfNeeded()
        if settingsStore.settings.hasCompletedOnboarding {
            beginRefresh(checkUpdates: false)
            scheduleAutoRefresh()
        }
    }

    func completeOnboardingAndScan() {
        settingsStore.settings.hasCompletedOnboarding = true
        seedPlaceholderHarnessesIfNeeded()
        beginRefresh(checkUpdates: false)
        scheduleAutoRefresh()
    }

    private func seedPlaceholderHarnessesIfNeeded() {
        guard harnesses.isEmpty else { return }
        harnesses = Self.placeholderHarnesses()
    }

    nonisolated static func placeholderHarnesses() -> [HarnessSnapshot] {
        HarnessRegistry.all.map { definition in
            HarnessSnapshot(
                definitionId: definition.id,
                name: definition.name,
                status: .unknown,
                installedVersion: nil,
                latestVersion: nil,
                updateStatus: .unknown,
                installSource: .unknown,
                binaryPath: nil,
                applicationPath: nil,
                providerIds: definition.providerIds,
                activeProject: nil,
                configItems: [],
                processCount: 0,
                isInstalled: false,
                lastScannedAt: Date(),
                definitionIncomplete: !definition.isComplete
            )
        }
    }

    func scheduleAutoRefresh() {
        refreshTask?.cancel()
        guard settingsStore.settings.refreshAutomatically else { return }
        let interval = max(30, settingsStore.settings.refreshIntervalSeconds)
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
                guard !Task.isCancelled else { break }
                await MainActor.run { self?.beginRefresh(checkUpdates: false) }
            }
        }
    }

    /// Instant UI scan (filesystem only), then optional background enrichment with a hard deadline.
    func beginRefresh(checkUpdates: Bool) {
        guard !isScanning && !isEnriching else { return }
        isScanning = true
        scanMessage = "Scanning your Mac for AI developer tools…"
        let settings = settingsStore.settings

        Task.detached(priority: .userInitiated) {
            let fast = await HarnessDiscoveryService.shared.discoverFast(settings: settings)
            await MainActor.run {
                AppStateBridge.shared?.applyFastHarnesses(fast)
                AppStateBridge.shared?.markScanFinished()
            }

            // Enrichment is best-effort and must never leave the UI stuck.
            await MainActor.run {
                AppStateBridge.shared?.isEnriching = true
            }

            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await RefreshPipeline.enrich(settings: settings, checkUpdates: checkUpdates)
                }
                group.addTask {
                    try? await Task.sleep(nanoseconds: 8_000_000_000)
                }
                // Whichever finishes first — enrichment or the 8s watchdog — we stop waiting.
                _ = await group.next()
                group.cancelAll()
            }

            await MainActor.run {
                AppStateBridge.shared?.isEnriching = false
            }
        }
    }

    func fullRefresh(checkUpdates: Bool) async {
        beginRefresh(checkUpdates: checkUpdates)
        // Wait at most ~2s for the fast pass to clear isScanning.
        for _ in 0..<40 {
            if !isScanning { break }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    func applyFastHarnesses(_ items: [HarnessSnapshot]) {
        harnesses = items
    }

    func applyScanResults(
        harnesses: [HarnessSnapshot],
        processes: [DetectedProcess],
        projects: [CodingProject],
        mcpServers: [MCPServer],
        skills: [SkillItem],
        packageManagers: [PackageManagerInfo],
        providers: [ProviderStatus]
    ) {
        self.harnesses = harnesses
        self.processes = processes
        self.projects = projects
        self.mcpServers = mcpServers
        self.skills = skills
        self.packageManagers = packageManagers
        self.providers = providers
    }

    func applyHarnessUpdate(_ snapshot: HarnessSnapshot) {
        if let idx = harnesses.firstIndex(where: { $0.definitionId == snapshot.definitionId }) {
            var merged = snapshot
            // Preserve running state if we already know about processes.
            if harnesses[idx].status == .running {
                merged.status = .running
                merged.processCount = harnesses[idx].processCount
                merged.activeProject = harnesses[idx].activeProject
            }
            harnesses[idx] = merged
        } else {
            harnesses.append(snapshot)
            harnesses.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    func markScanFinished() {
        isScanning = false
        lastRefresh = Date()
    }

    func checkForUpdates() async {
        guard !isCheckingUpdates else { return }
        isCheckingUpdates = true
        defer { isCheckingUpdates = false }
        let path = await PathEnvironmentService.shared.fastPATH(
            additionalPaths: settingsStore.settings.additionalBinaryPaths
        )
        let checked = await UpdateCheckService.shared.checkUpdates(
            snapshots: harnesses,
            pathEnvironment: path,
            force: true
        )
        for update in checked {
            if let index = harnesses.firstIndex(where: { $0.definitionId == update.definitionId && $0.installedVersion == update.installedVersion && $0.installSource == update.installSource }) {
                harnesses[index].latestVersion = update.latestVersion
                harnesses[index].updateStatus = update.updateStatus
            }
        }
        for i in harnesses.indices {
            if harnesses[i].updateStatus == .updateAvailable, harnesses[i].status == .installed {
                harnesses[i].status = .updateAvailable
            }
        }
    }

    func requestUpdate(for snapshot: HarnessSnapshot) async {
        guard let definition = HarnessRegistry.definition(for: snapshot.definitionId) else { return }
        let path = await PathEnvironmentService.shared.fastPATH(
            additionalPaths: settingsStore.settings.additionalBinaryPaths
        )
        guard let proposal = await UpdateCheckService.shared.proposedUpdateCommand(
            definition: definition,
            installSource: snapshot.installSource,
            pathEnvironment: path
        ) else {
            actionError = "No supported command is available for this installation. Open the harness website or use its built-in updater, then rescan."
            return
        }

        updateConfirmation = UpdateConfirmation(
            kind: .update,
            harnessId: snapshot.definitionId,
            harnessName: snapshot.name,
            installed: snapshot.installedVersion,
            latest: snapshot.latestVersion,
            displayCommand: proposal.display,
            executable: proposal.executable,
            arguments: proposal.arguments
        )
    }

    func requestInstall(for snapshot: HarnessSnapshot) async {
        guard let definition = HarnessRegistry.definition(for: snapshot.definitionId) else { return }
        let path = await PathEnvironmentService.shared.fastPATH(
            additionalPaths: settingsStore.settings.additionalBinaryPaths
        )
        guard let proposal = await UpdateCheckService.shared.proposedInstallCommand(
            definition: definition,
            packageManagers: packageManagers,
            pathEnvironment: path
        ) else {
            if let formula = HomebrewBootstrap.formula(for: definition) {
                updateConfirmation = UpdateConfirmation(
                    kind: .install, harnessId: snapshot.definitionId, harnessName: snapshot.name,
                    installed: nil, latest: nil,
                    displayCommand: "Install Homebrew using its official installer, then run:\nbrew install \(formula)",
                    executable: URL(fileURLWithPath: "/bin/bash"), arguments: [],
                    prerequisiteFormula: formula
                )
            } else {
                actionError = "No automatic installer is available for this tool. Open its website for installation instructions."
            }
            return
        }

        updateConfirmation = UpdateConfirmation(
            kind: .install,
            harnessId: snapshot.definitionId,
            harnessName: snapshot.name,
            installed: nil,
            latest: nil,
            displayCommand: proposal.display,
            executable: proposal.executable,
            arguments: proposal.arguments
        )
    }

    private func installWithHomebrewSetup(formula: String, title: String) {
        executionSheet = ExecutionSheetState(title: title, output: "Continue setup in Terminal. Homebrew may request your Mac password or Command Line Tools. The harness installs automatically after setup. Keep Terminal open until it finishes.")
        Task {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                let script = directory.appendingPathComponent("Install.command")
                try HomebrewBootstrap.script(formula: formula, directory: directory).write(to: script, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
                let result = try await CommandRunner.shared.run(executable: URL(fileURLWithPath: "/usr/bin/open"), arguments: ["-a", "Terminal", script.path], timeout: 15)
                guard result.succeeded else { throw TerminalLauncherError.failed(result.stderr) }
                let status = directory.appendingPathComponent("status")
                let deadline = Date().addingTimeInterval(3600)
                var code: Int32?
                while Date() < deadline {
                    if let text = try? String(contentsOf: status, encoding: .utf8), let value = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        code = value
                        break
                    }
                    try await Task.sleep(for: .seconds(1))
                }
                executionSheet?.isRunning = false
                executionSheet?.exitCode = code
                executionSheet?.output += code == 0
                    ? "\n\nHomebrew setup and harness installation completed successfully."
                    : "\n\nInstallation did not complete successfully. Check Terminal for details, then retry Install."
                await DiscoveryCache.shared.reset()
                await fullRefresh(checkUpdates: true)
            } catch {
                executionSheet?.isRunning = false
                executionSheet?.output += "\n\nSetup could not finish: \(error.localizedDescription). You can retry Install."
            }
        }
    }

    func confirmUpdate(_ confirmation: UpdateConfirmation) {
        updateConfirmation = nil
        if let formula = confirmation.prerequisiteFormula {
            installWithHomebrewSetup(formula: formula, title: confirmation.title)
            return
        }
        executionSheet = ExecutionSheetState(title: confirmation.title)
        let executable = confirmation.executable
        let arguments = confirmation.arguments

        Task {
            do {
                let path = await PathEnvironmentService.shared.fastPATH(additionalPaths: settingsStore.settings.additionalBinaryPaths)
                let result = try await CommandRunner.shared.run(
                    executable: executable,
                    arguments: arguments,
                    environment: ["PATH": path],
                    timeout: 600
                )
                await MainActor.run {
                    guard var sheet = self.executionSheet else { return }
                    sheet.isRunning = false
                    sheet.exitCode = result.exitCode
                    sheet.output = [result.stdout, result.stderr].filter { !$0.isEmpty }.joined(separator: "\n")
                    sheet.output.append(result.succeeded
                        ? "\n\nCompleted successfully (exit \(result.exitCode))."
                        : "\n\nFailed (exit \(result.exitCode)).")
                    self.executionSheet = sheet
                }
                await DiscoveryCache.shared.reset()
                await fullRefresh(checkUpdates: true)
            } catch {
                await MainActor.run {
                    guard var sheet = self.executionSheet else { return }
                    sheet.isRunning = false
                    sheet.output.append("\n\nError: \(error.localizedDescription)")
                    self.executionSheet = sheet
                }
            }
        }
    }

    func runDiagnostics(for snapshot: HarnessSnapshot) {
        guard let definition = HarnessRegistry.definition(for: snapshot.definitionId) else { return }
        diagnosticsSheet = DiagnosticsSheetState(harnessName: snapshot.name, isRunning: true)
        Task {
            let results = await DiagnosticsEngine().run(for: snapshot, definition: definition)
            await MainActor.run {
                guard var sheet = self.diagnosticsSheet else { return }
                sheet.results = results
                sheet.isRunning = false
                self.diagnosticsSheet = sheet
            }
        }
    }

    func revealPath(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    func openHarness(_ snapshot: HarnessSnapshot) {
        if let app = snapshot.applicationPath {
            NSWorkspace.shared.open(URL(fileURLWithPath: app))
        } else if snapshot.binaryPath != nil {
            projectPickerHarness = snapshot
        }
    }

    func terminateProcess(_ process: DetectedProcess, force: Bool) {
        Task {
            let ok = await ProcessMonitorService.shared.terminate(pid: process.pid, force: force)
            if ok { await fullRefresh(checkUpdates: false) }
        }
    }

    func launchHarness(_ snapshot: HarnessSnapshot, in project: CodingProject) {
        guard let binary = snapshot.binaryPath else { return }
        let command = (binary as NSString).lastPathComponent
        let launcher = SystemTerminalLauncher(preference: settingsStore.settings.preferredTerminal)
        Task {
            do {
                try await launcher.launch(
                    command: command,
                    workingDirectory: URL(fileURLWithPath: project.path)
                )
            } catch {
                logger.error("Launch failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func resetCacheAndRescan() {
        Task {
            await DiscoveryCache.shared.reset()
            await PathEnvironmentService.shared.invalidate()
            await fullRefresh(checkUpdates: false)
        }
    }
}

/// Strong bridge so detached tasks can always reach the live AppState.
@MainActor
enum AppStateBridge {
    static weak var shared: AppState?
}

extension AppState {
    /// Called from init / start to register the bridge.
    func registerBridge() {
        AppStateBridge.shared = self
    }
}

enum RefreshPipeline {
    static func enrich(settings: AppSettings, checkUpdates: Bool) async {
        // Register bridge must already be set on MainActor.
        let discovered = await HarnessDiscoveryService.shared.discoverAll(settings: settings) { _ in
            // Avoid per-item MainActor UI churn during enrichment (was contributing to beach-balls).
        }

        let path = await PathEnvironmentService.shared.fastPATH(additionalPaths: settings.additionalBinaryPaths)

        // Bound each subsystem; skip quietly on cancel/timeout.
        async let procs = ProcessMonitorService.shared.listHarnessProcesses()
        async let projs = ProjectScannerService.shared.scan(roots: settings.projectRoots)
        async let mcps = MCPDiscoveryService.shared.discover()
        async let skillItems = SkillsDiscoveryService.shared.discover(projectRoots: settings.projectRoots)
        async let pms = PackageManagerService.shared.detectPackageManagers(pathEnvironment: path)

        let processes = await procs
        let projects = await projs
        let mcpServers = await mcps
        let skills = await skillItems
        let packageManagers = await pms

        var harnesses = discovered
        var processCounts: [String: Int] = [:]
        var activeProjects: [String: String] = [:]
        for process in processes {
            guard let hid = process.harnessId else { continue }
            processCounts[hid, default: 0] += 1
            if activeProjects[hid] == nil, let project = process.projectName {
                activeProjects[hid] = project
            }
        }
        for i in harnesses.indices {
            let id = harnesses[i].definitionId
            let count = processCounts[id, default: 0]
            harnesses[i].processCount = count
            harnesses[i].activeProject = activeProjects[id]
            if count > 0 {
                harnesses[i].status = .running
            } else if harnesses[i].isInstalled {
                harnesses[i].status = .installed
            } else {
                harnesses[i].status = .unavailable
            }
        }

        var projectsMutable = projects
        for i in projectsMutable.indices {
            if let match = processes.first(where: { $0.workingDirectory == projectsMutable[i].path }) {
                projectsMutable[i].activeHarnessId = match.harnessId
                projectsMutable[i].activeHarnessName = match.harnessName
            }
        }

        let providers = await ProviderDetectionService.shared.detect(
            harnesses: harnesses,
            pathEnvironment: path
        )

        await MainActor.run {
            AppStateBridge.shared?.applyScanResults(
                harnesses: harnesses,
                processes: processes,
                projects: projectsMutable,
                mcpServers: mcpServers,
                skills: skills,
                packageManagers: packageManagers,
                providers: providers
            )
        }

        if checkUpdates {
            await MainActor.run {
                Task { await AppStateBridge.shared?.checkForUpdates() }
            }
        }
    }
}
