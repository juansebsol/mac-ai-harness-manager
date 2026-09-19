import SwiftUI

struct HarnessesListView: View {
    @Environment(AppState.self) private var appState
    @State private var sortOrder = [KeyPathComparator(\HarnessSnapshot.name)]

    var body: some View {
        VStack(spacing: 0) {
            summaryBar
            Divider()
            filterBar
            Divider()

            if appState.filteredHarnesses.isEmpty && !appState.isScanning {
                emptyState
            } else if appState.filteredHarnesses.isEmpty {
                scanningState
            } else {
                table
            }
        }
        .navigationTitle(appState.selectedSidebar.title)
        .searchable(text: Bindable(appState).searchText, prompt: "Search harnesses")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await appState.fullRefresh(checkUpdates: false) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(appState.isScanning)
                .help("Refresh")

                Button {
                    Task { await appState.checkForUpdates() }
                } label: {
                    Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(appState.isCheckingUpdates)
                .help("Check for Updates")
            }
        }
    }

    private var summaryBar: some View {
        let s = appState.summary
        return HStack(spacing: 20) {
            SummaryChip(title: "Installed", value: s.installed)
            SummaryChip(title: "Running", value: s.running)
            SummaryChip(title: "Updates", value: s.updates)
            SummaryChip(title: "Issues", value: s.issues)
            Spacer()
            if let last = appState.lastRefresh {
                Text("Updated \(last.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(HarnessFilter.allCases) { filter in
                FilterChip(
                    title: filter.title,
                    isSelected: appState.harnessFilter == filter
                ) {
                    appState.harnessFilter = filter
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var table: some View {
        Table(appState.filteredHarnesses, selection: Bindable(appState).selectedHarnessId, sortOrder: $sortOrder) {
            TableColumn("Harness", value: \.name) { item in
                HStack(spacing: 8) {
                    Image(systemName: HarnessRegistry.definition(for: item.definitionId)?.iconName ?? "app")
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.name)
                        if item.definitionIncomplete {
                            Text("Incomplete definition")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .width(min: 140, ideal: 180)

            TableColumn("Status", value: \.status.displayName) { item in
                StatusBadge(status: item.status)
            }
            .width(min: 100, ideal: 120)

            TableColumn("Version", value: \.displayVersion) { item in
                Text(item.displayVersion)
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
            }
            .width(min: 70, ideal: 90)

            TableColumn("Install Method", value: \.displayInstallMethod) { item in
                Text(item.displayInstallMethod)
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 100)

            TableColumn("Provider", value: \.displayProvider) { item in
                Text(item.displayProvider)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 80, ideal: 110)

            TableColumn("Active Project", value: \.displayActiveProject) { item in
                Text(item.displayActiveProject)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 90, ideal: 120)

            TableColumn("Update", value: \.updateStatus.displayName) { item in
                Text(item.updateStatus.displayName)
                    .foregroundStyle(item.updateStatus == .updateAvailable ? Color.orange : Color.secondary)
            }
            .width(min: 90, ideal: 120)

            TableColumn("Actions") { item in
                HStack(spacing: 4) {
                    if item.updateStatus == .updateAvailable {
                        Button("Update") {
                            Task { await appState.requestUpdate(for: item) }
                        }
                        .buttonStyle(.borderless)
                    }
                    Menu {
                        Button("Open") { appState.openHarness(item) }
                        Button("Run Diagnostics") { appState.runDiagnostics(for: item) }
                        if let path = item.binaryPath {
                            Button("Reveal Binary") { appState.revealPath(path) }
                            Button("Copy Path") { appState.copyToPasteboard(path) }
                        }
                        if let config = item.configItems.first(where: \.exists) {
                            Button("Reveal Config") { appState.revealPath(config.path) }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            .width(min: 90, ideal: 110)
        }
        .onChange(of: sortOrder) { _, newValue in
            appState.harnesses.sort(using: newValue)
        }
        .contextMenu(forSelectionType: String.self) { ids in
            if let id = ids.first, let item = appState.harnesses.first(where: { $0.definitionId == id }) {
                Button("Run Diagnostics") { appState.runDiagnostics(for: item) }
                if item.updateStatus == .updateAvailable {
                    Button("Update…") { Task { await appState.requestUpdate(for: item) } }
                }
            }
        }
    }

    private var scanningState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(appState.scanMessage)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No AI coding harnesses detected", systemImage: "magnifyingglass")
        } description: {
            Text("Try rescanning, or browse the supported harness list.")
        } actions: {
            Button("Rescan") {
                Task { await appState.fullRefresh(checkUpdates: false) }
            }
            .buttonStyle(.borderedProminent)
            Button("View Supported Harnesses") {
                appState.harnessFilter = .all
                appState.selectedSidebar = .allHarnesses
                appState.searchText = ""
            }
        }
    }
}

struct SummaryChip: View {
    let title: String
    let value: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.caption.weight(.semibold).monospacedDigit())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.25))
        )
    }
}

struct StatusBadge: View {
    let status: HarnessStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch status {
        case .running: return .green
        case .installed: return .secondary
        case .updateAvailable: return .orange
        case .misconfigured: return .red
        case .unavailable: return .secondary
        case .unknown: return .secondary
        }
    }
}
