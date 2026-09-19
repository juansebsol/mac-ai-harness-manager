import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(SettingsStore.self) private var settingsStore
    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general, discovery, packageManagers, privacy, advanced
        var id: String { rawValue }
        var title: String {
            switch self {
            case .general: return "General"
            case .discovery: return "Discovery"
            case .packageManagers: return "Package Managers"
            case .privacy: return "Privacy"
            case .advanced: return "Advanced"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Settings", selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            Form {
                switch selectedTab {
                case .general: generalSection
                case .discovery: discoverySection
                case .packageManagers: packageManagersSection
                case .privacy: privacySection
                case .advanced: advancedSection
                }
            }
            .formStyle(.grouped)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Settings")
    }

    @ViewBuilder
    private var generalSection: some View {
        Section("Startup") {
            Toggle("Launch at Login", isOn: Bindable(settingsStore).settings.launchAtLogin)
                .onChange(of: settingsStore.settings.launchAtLogin) { _, enabled in
                    updateLaunchAtLogin(enabled)
                }
            Toggle("Show Menu Bar Icon", isOn: Bindable(settingsStore).settings.showMenuBarExtra)
        }
        Section("Refresh") {
            Toggle("Refresh Automatically", isOn: Bindable(settingsStore).settings.refreshAutomatically)
                .onChange(of: settingsStore.settings.refreshAutomatically) { _, _ in
                    appState.scheduleAutoRefresh()
                }
            Stepper(
                value: Bindable(settingsStore).settings.refreshIntervalSeconds,
                in: 15...600,
                step: 15
            ) {
                Text("Refresh Interval: \(settingsStore.settings.refreshIntervalSeconds)s")
            }
            .onChange(of: settingsStore.settings.refreshIntervalSeconds) { _, _ in
                appState.scheduleAutoRefresh()
            }
        }
        Section("Terminal") {
            Picker("Preferred Terminal", selection: Bindable(settingsStore).settings.preferredTerminal) {
                ForEach(PreferredTerminal.allCases) { terminal in
                    Text(terminal.displayName).tag(terminal)
                }
            }
            Text("Launching harnesses in a terminal may request Automation permission so the command can run in the project directory.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var discoverySection: some View {
        Section("Project Roots") {
            ForEach(Array(settingsStore.settings.projectRoots.enumerated()), id: \.offset) { index, root in
                HStack {
                    TextField("Path", text: Bindable(settingsStore).settings.projectRoots[index])
                    Button(role: .destructive) {
                        settingsStore.settings.projectRoots.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            Button("Add Project Root") {
                settingsStore.settings.projectRoots.append("~/")
            }
            Text("Never scans your entire home directory by default.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("Additional Binary Paths") {
            ForEach(Array(settingsStore.settings.additionalBinaryPaths.enumerated()), id: \.offset) { index, _ in
                HStack {
                    TextField("Path", text: Bindable(settingsStore).settings.additionalBinaryPaths[index])
                    Button(role: .destructive) {
                        settingsStore.settings.additionalBinaryPaths.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            Button("Add Path") {
                settingsStore.settings.additionalBinaryPaths.append("")
            }
        }
        Section("Additional Config Directories") {
            ForEach(Array(settingsStore.settings.additionalConfigDirectories.enumerated()), id: \.offset) { index, _ in
                HStack {
                    TextField("Path", text: Bindable(settingsStore).settings.additionalConfigDirectories[index])
                    Button(role: .destructive) {
                        settingsStore.settings.additionalConfigDirectories.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            Button("Add Directory") {
                settingsStore.settings.additionalConfigDirectories.append("")
            }
        }
    }

    @ViewBuilder
    private var packageManagersSection: some View {
        Section {
            if appState.packageManagers.isEmpty {
                Text("Scan your Mac to detect package managers.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appState.packageManagers) { pm in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(pm.name)
                                .font(.body.weight(.medium))
                            Spacer()
                            Text(pm.isInstalled ? "Installed" : "Not found")
                                .foregroundStyle(pm.isInstalled ? Color.primary : Color.secondary)
                        }
                        if let path = pm.path {
                            Text(path)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        if let version = pm.version {
                            Text(version)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private var privacySection: some View {
        Section {
            Text("All discovery and diagnostics run locally on your Mac. Harness Manager does not upload your project, configuration, process, or credential information.")
                .font(.body)
            Text("API keys and tokens are never displayed. Scanning only checks whether configuration appears to exist.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("No analytics or telemetry are enabled.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var advancedSection: some View {
        Section {
            Toggle("Show command execution logs", isOn: Bindable(settingsStore).settings.showCommandLogs)
            Button("Reset Cache") {
                appState.resetCacheAndRescan()
            }
            Button("Rescan Machine") {
                Task { await appState.fullRefresh(checkUpdates: true) }
            }
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Launch at login may fail outside a proper app bundle / notarization context.
        }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.largeTitle)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Harness Manager")
                        .font(.title.weight(.semibold))
                    Text("Version 0.1.0")
                        .foregroundStyle(.secondary)
                }
            }

            Text("A control center for AI coding agents, CLI harnesses, MCP servers, skills, and providers on your Mac.")
                .foregroundStyle(.secondary)

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("Supported definitions").foregroundStyle(.secondary)
                    Text("\(HarnessRegistry.all.count)")
                }
                GridRow {
                    Text("Complete").foregroundStyle(.secondary)
                    Text("\(HarnessRegistry.complete.count)")
                }
                GridRow {
                    Text("Incomplete placeholders").foregroundStyle(.secondary)
                    Text("\(HarnessRegistry.incomplete.count)")
                }
            }

            Spacer()

            Text("Operates entirely locally. Read-only by default.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("About")
    }
}

struct MenuBarContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if appState.runningMenuItems.isEmpty {
            Text("No running agents")
        } else {
            Section("Running Agents") {
                ForEach(Array(appState.runningMenuItems.enumerated()), id: \.offset) { _, item in
                    Text("\(item.name) — \(item.project)")
                }
            }
        }

        Divider()

        Section("Quick Launch") {
            Button("Open Dashboard") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            Button("Refresh") {
                Task { await appState.fullRefresh(checkUpdates: false) }
            }
        }

        Divider()

        Button("Quit Harness Manager") {
            NSApp.terminate(nil)
        }
    }
}
