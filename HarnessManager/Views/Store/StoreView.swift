import SwiftUI

struct StoreView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var segment: StoreSegment = .all

    enum StoreSegment: String, CaseIterable, Identifiable {
        case all
        case notInstalled
        case updates
        case installed

        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: return "All"
            case .notInstalled: return "Get"
            case .updates: return "Updates"
            case .installed: return "Installed"
            }
        }
    }

    private var items: [HarnessSnapshot] {
        var list = appState.harnesses
        switch segment {
        case .all: break
        case .notInstalled: list = list.filter { !$0.isInstalled }
        case .updates: list = list.filter { $0.updateStatus == .updateAvailable }
        case .installed: list = list.filter(\.isInstalled)
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                $0.name.lowercased().contains(q)
                    || $0.displayProvider.lowercased().contains(q)
                    || ($0.definitionIncomplete && "incomplete".contains(q))
            }
        }
        return list.sorted { lhs, rhs in
            // Updates first, then not installed, then installed
            let lr = rank(lhs)
            let rr = rank(rhs)
            if lr != rr { return lr < rr }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func rank(_ item: HarnessSnapshot) -> Int {
        if item.updateStatus == .updateAvailable { return 0 }
        if !item.isInstalled { return 1 }
        return 2
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if items.isEmpty {
                ContentUnavailableView {
                    Label(emptyTitle, systemImage: "bag")
                } description: {
                    Text(emptyDescription)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            StoreRow(snapshot: item)
                            Divider().padding(.leading, 72)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Store")
        .searchable(text: $searchText, prompt: "Search harnesses")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await appState.checkForUpdates() }
                } label: {
                    Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(appState.isCheckingUpdates)
                .help("Check for Updates")

                Button {
                    Task { await appState.fullRefresh(checkUpdates: false) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(appState.isScanning)
            }
        }
        .task {
            if appState.harnesses.contains(where: { $0.isInstalled && $0.updateStatus == .unknown }) {
                await appState.checkForUpdates()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Browse and install AI coding harnesses. Updates for installed tools appear here too.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Picker("Filter", selection: $segment) {
                ForEach(StoreSegment.allCases) { seg in
                    Text(seg.title).tag(seg)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var emptyTitle: String {
        switch segment {
        case .updates: return "No updates available"
        case .notInstalled: return "Nothing left to install"
        case .installed: return "No harnesses installed"
        case .all: return "No harnesses"
        }
    }

    private var emptyDescription: String {
        switch segment {
        case .updates: return "Installed harnesses are up to date, or update checks haven’t run yet."
        case .notInstalled: return "Every supported harness in the catalog appears to be installed."
        default: return "Try refreshing your machine scan."
        }
    }
}

struct StoreRow: View {
    @Environment(AppState.self) private var appState
    let snapshot: HarnessSnapshot

    private var definition: HarnessDefinition? {
        HarnessRegistry.definition(for: snapshot.definitionId)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: definition?.iconName ?? "app")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(snapshot.name)
                        .font(.body.weight(.semibold))
                    if snapshot.updateStatus == .updateAvailable {
                        Text("Update")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                    if snapshot.definitionIncomplete {
                        Text("Coming soon")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if let website = definition?.website {
                    Text(website.host ?? website.absoluteString)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 12)

            actionButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            appState.selectedHarnessId = snapshot.definitionId
        }
    }

    private var subtitle: String {
        if snapshot.isInstalled {
            var parts: [String] = ["Installed"]
            if let version = snapshot.installedVersion {
                parts.append(version)
            }
            if snapshot.updateStatus == .updateAvailable, let latest = snapshot.latestVersion {
                parts.append("→ \(latest)")
            }
            parts.append(snapshot.displayInstallMethod)
            return parts.joined(separator: " · ")
        }

        if let definition, !definition.installationMethods.isEmpty {
            let methods = definition.installationMethods.map(\.shortName).joined(separator: ", ")
            return "Available via \(methods)"
        }
        if snapshot.definitionIncomplete {
            return definition?.notes ?? "Install instructions not available yet"
        }
        return "Not installed"
    }

    @ViewBuilder
    private var actionButton: some View {
        if snapshot.updateStatus == .updateAvailable {
            Button("Update") {
                Task { await appState.requestUpdate(for: snapshot) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        } else if snapshot.isInstalled {
            Button("Open") {
                appState.selectedSidebar = .allHarnesses
                appState.selectedHarnessId = snapshot.definitionId
                appState.openHarness(snapshot)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        } else if canInstall {
            Button("Get") {
                Task { await appState.requestInstall(for: snapshot) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        } else if let website = definition?.website {
            Link("Website", destination: website)
                .buttonStyle(.bordered)
                .controlSize(.small)
        } else {
            Text("Unavailable")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var canInstall: Bool {
        guard let definition = definition, definition.isComplete else { return false }
        guard !definition.installationMethods.isEmpty else { return false }
        let installed = Set(appState.packageManagers.filter(\.isInstalled).map(\.id))
        for method in definition.installationMethods {
            switch method {
            case .homebrew: if installed.contains("homebrew") { return true }
            case .npm: if installed.contains("npm") { return true }
            case .pnpm: if installed.contains("pnpm") { return true }
            case .bun: if installed.contains("bun") { return true }
            case .macApplication, .standalone: continue
            }
        }
        return false
    }
}
