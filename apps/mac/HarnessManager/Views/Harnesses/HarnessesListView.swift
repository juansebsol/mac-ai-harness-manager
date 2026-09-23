import SwiftUI

struct HarnessesListView: View {
    @Environment(AppState.self) private var appState

    private var items: [HarnessSnapshot] {
        appState.filteredHarnesses.sorted {
            if $0.isInstalled != $1.isInstalled { return $0.isInstalled }
            if $0.status.sortOrder != $1.status.sortOrder { return $0.status.sortOrder < $1.status.sortOrder }
            return $0.name < $1.name
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            workspaceHeader
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text(listTitle).font(.system(size: 14, weight: .semibold))
                        Text("\(items.count)").font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                        Spacer()
                        if appState.isScanning || appState.isEnriching {
                            ProgressView().controlSize(.small)
                            Text(appState.isScanning ? "Scanning your Mac…" : "Updating details…").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if items.isEmpty {
                        ContentUnavailableView {
                            Label(emptyTitle, systemImage: emptySymbol)
                        } description: {
                            Text(emptyDescription)
                        } actions: {
                            if !appState.searchText.isEmpty {
                                Button("Clear search") { appState.searchText = "" }
                            } else if appState.harnessFilter != .all {
                                Button("Show all tools") { appState.harnessFilter = .all }
                            } else if !appState.isScanning {
                                Button("Discover tools") { appState.selectedSidebar = .store }
                            }
                        }.frame(minHeight: 240)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(items) { item in
                                workspaceRow(item)
                                if item.id != items.last?.id { Divider().padding(.leading, 76) }
                            }
                        }
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.07)))
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "desktopcomputer")
                        Text("Tools detected on this Mac")
                        Spacer()
                        if let date = appState.lastRefresh { Text("Scanned \(date.formatted(date: .omitted, time: .shortened))") }
                    }.font(.caption).foregroundStyle(.secondary)
                }.padding(24)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Workspace")
        .searchable(text: Bindable(appState).searchText, prompt: "Find a tool")
        .toolbar {
            Button { Task { await appState.fullRefresh(checkUpdates: false) } } label: { Label("Refresh", systemImage: "arrow.clockwise") }.disabled(appState.isScanning)
            Button { Task { await appState.checkForUpdates() } } label: { Label("Check for updates", systemImage: "arrow.triangle.2.circlepath") }.disabled(appState.isCheckingUpdates)
        }
    }

    private var workspaceHeader: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Your workspace").font(.system(size: 28, weight: .bold)).tracking(-0.6)
                    Text("Launch your tools. Keep everything ready.").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button { appState.selectedSidebar = .store } label: {
                    Label("Add tools", systemImage: "plus")
                }.buttonStyle(.bordered).controlSize(.large)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) { filterButtons }
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 6) { filterButtons } }
            }
        }.padding(24)
    }

    private var filterButtons: some View {
        ForEach(HarnessFilter.allCases) { filter in
            Button { appState.harnessFilter = filter } label: {
                HStack(spacing: 7) {
                    Image(systemName: symbol(filter)).font(.system(size: 12))
                    Text(filter.title).font(.system(size: 12, weight: .medium))
                    Text("\(count(filter))")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                }
                .padding(.horizontal, 11).padding(.vertical, 9)
                .foregroundStyle(appState.harnessFilter == filter ? Color.primary : .secondary)
                .background(appState.harnessFilter == filter ? Color(nsColor: .controlBackgroundColor) : .clear, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(appState.harnessFilter == filter ? Color.accentColor.opacity(0.5) : .clear))
            }.buttonStyle(.plain)
                .accessibilityLabel("\(filter.title), \(count(filter)) tools")
                .accessibilityAddTraits(appState.harnessFilter == filter ? .isSelected : [])
        }
    }

    private func count(_ filter: HarnessFilter) -> Int {
        switch filter {
        case .all: return appState.workspaceHarnesses.count
        case .running: return appState.summary.running
        case .updateAvailable: return appState.summary.updates
        case .misconfigured: return appState.summary.issues
        }
    }
    private func symbol(_ filter: HarnessFilter) -> String {
        switch filter {
        case .all: return "square.stack.3d.up"
        case .running: return "play.circle"
        case .updateAvailable: return "arrow.down.circle"
        case .misconfigured: return "exclamationmark.circle"
        }
    }
    private var listTitle: String {
        switch appState.harnessFilter {
        case .all: return "On this Mac"
        case .running: return "Running now"
        case .updateAvailable: return "Ready to update"
        case .misconfigured: return "Needs attention"
        }
    }
    private var emptyTitle: String {
        if appState.isScanning { return "Finding your tools…" }
        if !appState.searchText.isEmpty { return "No matching tools" }
        switch appState.harnessFilter {
        case .all: return "Your workspace starts here"
        case .running: return "Nothing running right now"
        case .updateAvailable: return "No updates found"
        case .misconfigured: return "No issues detected"
        }
    }
    private var emptySymbol: String {
        appState.harnessFilter == .misconfigured && appState.searchText.isEmpty ? "checkmark.circle" : symbol(appState.harnessFilter)
    }
    private var emptyDescription: String {
        if appState.isScanning { return appState.scanMessage }
        if !appState.searchText.isEmpty { return "Try a different name or clear your search. Filters also apply to search results." }
        switch appState.harnessFilter {
        case .all: return "Add a coding tool from Discover, or refresh to find one you already installed."
        case .running: return "Open a tool from All tools. Its running status will appear here when detected."
        case .updateAvailable: return "Use Check for updates in the toolbar to check supported installations."
        case .misconfigured: return "Your latest scan found no configuration issues. You can run diagnostics from any tool’s menu."
        }
    }

    private func workspaceRow(_ item: HarnessSnapshot) -> some View {
        HStack(spacing: 14) {
            Button { appState.openInspector(for: item.id) } label: {
                HStack(spacing: 14) {
                    HarnessLogoView(snapshot: item, size: 40)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.name).font(.system(size: 14, weight: .semibold))
                        Text(rowDetail(item)).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        if item.needsAttention {
                            Text(item.definitionIncomplete ? "Setup support is incomplete · review diagnostics" : "Configuration needs attention · review diagnostics")
                                .font(.caption).foregroundStyle(.orange).lineLimit(2)
                        }
                    }
                    Spacer(minLength: 10)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).help("Inspect \(item.name)")
            VStack(alignment: .trailing, spacing: 5) {
                StatusBadge(status: item.status)
                if let version = item.installedVersion { Text("v\(version)").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary) }
            }
            if item.needsAttention {
                Button("Diagnose") { appState.runDiagnostics(for: item) }.buttonStyle(.bordered).controlSize(.small).frame(width: 82)
            } else if item.updateStatus == .updateAvailable {
                Button("Update…") { Task { await appState.requestUpdate(for: item) } }.buttonStyle(.borderedProminent).controlSize(.small).frame(width: 82)
            } else {
                Button(item.isInstalled ? "Open" : "Details") {
                    if item.isInstalled { appState.openHarness(item) } else { appState.openInspector(for: item.id) }
                }.buttonStyle(.bordered).controlSize(.small).frame(width: 82)
            }
            Menu {
                Button("Inspect") { appState.openInspector(for: item.id) }
                if item.isInstalled { Button("Open") { appState.openHarness(item) } }
                if item.updateStatus == .updateAvailable { Button("Update…") { Task { await appState.requestUpdate(for: item) } } }
                Button("Run diagnostics") { appState.runDiagnostics(for: item) }
                if let path = item.binaryPath { Button("Reveal binary") { appState.revealPath(path) }; Button("Copy path") { appState.copyToPasteboard(path) } }
            } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).fixedSize().frame(width: 16)
        }.padding(18)
            .background(appState.selectedHarnessId == item.id ? Color.accentColor.opacity(0.06) : .clear)
    }
    private func rowDetail(_ item: HarnessSnapshot) -> String {
        if item.status == .running {
            var details = [item.processCount > 0 ? "\(item.processCount) active process\(item.processCount == 1 ? "" : "es")" : "Running process detected"]
            if let project = item.activeProject { details.append(project) }
            return details.joined(separator: " · ")
        }
        if item.updateStatus == .updateAvailable, let version = item.latestVersion { return "\(item.displayInstallMethod) · Version \(version) available" }
        return item.displayInstallMethod
    }

}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .foregroundStyle(isSelected ? Color.primary : .secondary)
                .background(isSelected ? Color.primary.opacity(0.09) : .clear, in: Capsule())
        }.buttonStyle(.plain).accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct StatusBadge: View {
    let status: HarnessStatus
    var body: some View {
        HStack(spacing: 5) {
            if status == .running { Circle().fill(Color.green).frame(width: 5, height: 5) }
            Text(status.displayName).font(.system(size: 11, weight: .medium))
        }.padding(.horizontal, 8).padding(.vertical, 4)
            .foregroundStyle(color).background(color.opacity(0.09), in: Capsule())
    }
    private var color: Color {
        switch status { case .running: return .green; case .updateAvailable: return .orange; case .misconfigured: return .red; default: return .secondary }
    }
}
