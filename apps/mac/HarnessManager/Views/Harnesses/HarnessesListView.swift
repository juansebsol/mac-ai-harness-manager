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
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                PageHeading(eyebrow: "YOUR WORKSPACE", title: "Ready when you are.", subtitle: "All your coding tools. A little more under control.")
                HStack(spacing: 12) {
                    metric("Installed", value: appState.summary.installed, symbol: "square.stack.3d.up", filter: .installed)
                    metric("Running", value: appState.summary.running, symbol: "play.circle", filter: .running)
                    metric("Updates", value: appState.summary.updates, symbol: "arrow.down.circle", filter: .updateAvailable)
                    metric("Needs attention", value: appState.summary.issues, symbol: "exclamationmark.circle", filter: .misconfigured)
                }
                HStack {
                    Text(appState.selectedSidebar == .allHarnesses ? "Your harnesses" : appState.selectedSidebar.title).font(.title3.weight(.semibold))
                    Spacer()
                    Button("Discover tools", systemImage: "plus") { appState.selectedSidebar = .store }.buttonStyle(.borderless)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(HarnessFilter.allCases) { filter in
                            FilterChip(title: filter.title, isSelected: appState.harnessFilter == filter) { appState.harnessFilter = filter }
                        }
                    }
                }
                if items.isEmpty {
                    ContentUnavailableView(appState.isScanning ? "Finding your tools…" : "Nothing here yet", systemImage: "square.stack.3d.up", description: Text(appState.isScanning ? appState.scanMessage : "Try another filter, or head to Discover to find your next harness."))
                        .frame(minHeight: 180)
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
                HStack(spacing: 7) {
                    Image(systemName: "lock.shield")
                    Text("Local discovery. You review every install and update.")
                    Spacer()
                    if let date = appState.lastRefresh { Text("Scanned \(date.formatted(date: .omitted, time: .shortened))") }
                }.font(.caption).foregroundStyle(.secondary)
            }.padding(28)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Workspace")
        .searchable(text: Bindable(appState).searchText, prompt: "Find a harness")
        .toolbar {
            Button { Task { await appState.fullRefresh(checkUpdates: false) } } label: { Label("Refresh", systemImage: "arrow.clockwise") }.disabled(appState.isScanning)
            Button { Task { await appState.checkForUpdates() } } label: { Label("Check for updates", systemImage: "arrow.triangle.2.circlepath") }.disabled(appState.isCheckingUpdates)
        }
    }

    private func metric(_ title: String, value: Int, symbol: String, filter: HarnessFilter) -> some View {
        Button { appState.selectedSidebar = .allHarnesses; appState.harnessFilter = filter } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: symbol).font(.system(size: 17)).foregroundStyle(filter == .updateAvailable && value > 0 ? Color.accentColor : .secondary)
                    Spacer()
                    Text("\(value)").font(.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit())
                }
                Text(title).font(.callout).foregroundStyle(.secondary)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(appState.harnessFilter == filter ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.07)))
        }.buttonStyle(.plain).accessibilityLabel("\(value) \(title). Filter workspace")
    }

    private func workspaceRow(_ item: HarnessSnapshot) -> some View {
        HStack(spacing: 14) {
            Button { appState.openInspector(for: item.id) } label: {
                HStack(spacing: 14) {
                    HarnessLogoView(snapshot: item, size: 40)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.name).font(.system(size: 14, weight: .semibold))
                        Text(item.isInstalled ? item.displayInstallMethod : item.status == .running ? "Running process detected" : "Available in Discover").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 10)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).help("Inspect \(item.name)")
            VStack(alignment: .trailing, spacing: 5) {
                StatusBadge(status: item.status)
                if let version = item.installedVersion { Text("v\(version)").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary) }
            }
            if item.updateStatus == .updateAvailable {
                Button("Update…") { Task { await appState.requestUpdate(for: item) } }.buttonStyle(.borderedProminent).controlSize(.small).frame(width: 82)
            } else {
                Button(item.isInstalled ? "Open" : "Details") {
                    if item.isInstalled { appState.openHarness(item) } else { appState.openInspector(for: item.id) }
                }.buttonStyle(.bordered).controlSize(.small).frame(width: 82)
            }
            Menu {
                Button("Inspect") { appState.openInspector(for: item.id) }
                Button("Run diagnostics") { appState.runDiagnostics(for: item) }
                if let path = item.binaryPath { Button("Reveal binary") { appState.revealPath(path) }; Button("Copy path") { appState.copyToPasteboard(path) } }
            } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).fixedSize().frame(width: 16)
        }.padding(18)
            .background(appState.selectedHarnessId == item.id ? Color.accentColor.opacity(0.06) : .clear)
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
