import SwiftUI

struct StoreView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var includePreviews = false
    @State private var category: DiscoverCategory = .harnesses
    @State private var catalog = DiscoverCatalogModel()
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
        var list = appState.harnesses.filter { includePreviews || !$0.definitionIncomplete || $0.isInstalled }
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
            let left = HarnessRegistry.definition(for: lhs.definitionId)
            let right = HarnessRegistry.definition(for: rhs.definitionId)
            if left?.isMetaHarness != right?.isMetaHarness { return left?.isMetaHarness != true }
            let lr = left?.discoveryRank ?? Int.max
            let rr = right?.discoveryRank ?? Int.max
            if lr != rr { return lr < rr }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if category != .harnesses {
                repositoryCatalog
            } else if items.isEmpty {
                ContentUnavailableView {
                    Label(emptyTitle, systemImage: "bag")
                } description: {
                    Text(emptyDescription)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        catalogSection("Coding harnesses", meta: false)
                        catalogSection("Meta harnesses", meta: true)
                        if segment == .all {
                            repositorySection(title: "More harnesses on GitHub", entries: repositories)
                        }
                    }
                    .padding(28)
                }
            }
        }
        .navigationTitle("Discover")
        .searchable(text: $searchText, prompt: "Search \(category.rawValue.lowercased())")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await appState.checkForUpdates() }
                } label: {
                    Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(appState.isCheckingUpdates)
                .help("Check for Updates")
                .opacity(category == .harnesses ? 1 : 0)
                .disabled(category != .harnesses)

                Button {
                    Task {
                        if category == .harnesses { await appState.fullRefresh(checkUpdates: false) }
                        await catalog.refresh(category, force: true)
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(catalog.loading.contains(category) || (category == .harnesses && appState.isScanning))
            }
        }
        .task {
            if !appState.isMarketingCapture && appState.harnesses.contains(where: { $0.isInstalled && $0.updateStatus == .unknown }) {
                await appState.checkForUpdates()
            }
        }
        .task(id: category) {
            if !appState.isMarketingCapture { await catalog.refresh(category) }
        }
    }

    @ViewBuilder
    private func catalogSection(_ title: String, meta: Bool) -> some View {
        let group = items.filter { (HarnessRegistry.definition(for: $0.definitionId)?.isMetaHarness == true) == meta }
        if !group.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(title).font(.title3.weight(.semibold))
                    Spacer()
                    Text("Popular first").font(.caption).foregroundStyle(.secondary)
                        .help("Curated popularity order, not live usage statistics.")
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                    ForEach(group) { StoreRow(snapshot: $0) }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            PageHeading(eyebrow: "THE TOOLBOX", title: "Find your next favorite.", subtitle: "Coding tools, useful connections, and skills worth adding to your workflow.")

            Picker("Discover category", selection: $category) {
                ForEach(DiscoverCategory.allCases) { value in
                    Text(value.rawValue).tag(value)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)

            if category == .harnesses {
            Picker("Filter", selection: $segment) {
                ForEach(StoreSegment.allCases) { seg in
                    Text(seg.title).tag(seg)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)
            Toggle("Include tools with limited support", isOn: $includePreviews).font(.caption).toggleStyle(.checkbox)
            } else {
                Text(category == .skills ? "Individual skills, collections, and toolkits for your coding agents." : "Connect your agents to browsers, documentation, and external services.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(28)
    }

    private var repositories: [DiscoverRepository] {
        let known = Set(["anthropics/claude-code", "openai/codex", "google-gemini/gemini-cli", "stablyai/orca", "pingdotgg/t3code", "getpaseo/paseo", "superset-sh/superset", "manaflow-ai/cmux", "generalaction/emdash", "herdrdev/herdr", "anomalyco/opencode", "sst/opencode", "nousresearch/hermes-agent", "openchamber/openchamber", "bloopai/vibe-kanban", "warpdotdev/warp"])
        return DiscoverRepository.sorted(catalog.entries[category] ?? []).filter {
            (category != .harnesses || !known.contains($0.id)) &&
            (searchText.isEmpty || "\($0.name) \($0.repository) \($0.summary) \($0.kind)".localizedCaseInsensitiveContains(searchText))
        }
    }

    private var repositoryCatalog: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                repositorySection(title: category == .skills ? "Skills for your next project" : "Connections for your agents", entries: repositories)
                if repositories.isEmpty {
                    ContentUnavailableView("No matching projects", systemImage: "magnifyingglass", description: Text("Try another search or refresh the catalog."))
                }
            }.padding(28)
        }
    }

    private func repositorySection(title: String, entries: [DiscoverRepository]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title).font(.title3.weight(.semibold))
                Spacer()
                if catalog.loading.contains(category) { ProgressView().controlSize(.small) }
                Text("GitHub stars · highest first").font(.caption).foregroundStyle(.secondary)
            }
            Text("Popularity reflects repository stars, not compatibility or a quality review. Open a project for its setup instructions.")
                .font(.caption).foregroundStyle(.secondary)
            if let error = catalog.errors[category] {
                Label(error, systemImage: "wifi.exclamationmark").font(.caption).foregroundStyle(.secondary)
            }
            if let date = catalog.refreshed[category] {
                Text("Updated \(date.formatted(date: .abbreviated, time: .shortened)) · Refreshes daily")
                    .font(.caption2).foregroundStyle(.secondary)
            } else if !catalog.loading.contains(category) {
                Text("Starter collection · Star counts appear when GitHub is available")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                ForEach(entries) { entry in DiscoverRepositoryCard(entry: entry, category: category) }
            }
        }
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
        case .updates: return "No confirmed updates. Unknown versions and unsupported update sources still need a manual check."
        case .notInstalled: return "Every supported harness in the catalog appears to be installed."
        default: return "Try refreshing your machine scan."
        }
    }
}

private struct DiscoverRepositoryCard: View {
    let entry: DiscoverRepository
    let category: DiscoverCategory
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                AsyncImage(url: entry.avatarURL) { image in image.resizable().scaledToFit() } placeholder: {
                    Image(systemName: category.symbol).font(.title2).foregroundStyle(Color.accentColor)
                }
                .frame(width: 42, height: 42).clipShape(RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.name).font(.system(size: 15, weight: .semibold)).lineLimit(2)
                    Text(entry.kind).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            Text(entry.summary).font(.callout).foregroundStyle(.secondary).lineLimit(3)
                .frame(height: 54, alignment: .top)
            Text(entry.repository).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            Divider()
            HStack {
                if entry.archived {
                    Label("Archived", systemImage: "archivebox").font(.caption)
                } else if let stars = entry.stars {
                    Label(stars.formatted(), systemImage: "star").font(.caption.monospacedDigit())
                        .accessibilityLabel("\(stars) GitHub stars")
                } else {
                    Text("Stars unavailable").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Link("View project ↗", destination: entry.url).buttonStyle(.bordered).controlSize(.small)
            }
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.08)))
    }
}

struct StoreRow: View {
    @Environment(AppState.self) private var appState
    let snapshot: HarnessSnapshot

    private var definition: HarnessDefinition? {
        HarnessRegistry.definition(for: snapshot.definitionId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                HarnessLogoView(snapshot: snapshot, size: 46)
                VStack(alignment: .leading, spacing: 5) {
                    Text(snapshot.name).font(.system(size: 15, weight: .semibold))
                    Text(definition?.isMetaHarness == true ? "Meta harness" : snapshot.displayProvider).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button { appState.openInspector(for: snapshot.id) } label: { Image(systemName: "info.circle") }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("About \(snapshot.name)")
            }
            Text(description).font(.callout).foregroundStyle(.secondary).lineLimit(2).frame(height: 36, alignment: .top)
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.isInstalled ? "ON YOUR MAC" : "AVAILABLE").font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
                    Text(subtitle).font(.system(size: 11)).lineLimit(1)
                }
                Spacer(minLength: 8)
                actionButton
            }
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.08)))
    }

    private var description: String {
        switch snapshot.definitionId {
        case "claude-code": return "Think through complex changes with Claude, right in your terminal."
        case "codex": return "Bring OpenAI’s coding agent into your local development workflow."
        case "gemini-cli": return "Explore, write, and debug with Gemini from the command line."
        case "cursor": return "An editor built around working alongside AI."
        case "opencode": return "An open-source coding agent with your choice of model."
        case "warp": return "A terminal that brings commands and agents together."
        default: return definition?.notes ?? "Explore another way to work with AI on your Mac."
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
            Button(snapshot.applicationPath == nil ? "Launch…" : "Open") {
                appState.selectedSidebar = .allHarnesses
                appState.selectedHarnessId = snapshot.definitionId
                appState.openHarness(snapshot)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        } else if canInstall {
            Button("Install…") {
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
            case .homebrew: return true // Setup is included when Homebrew is missing.
            case .npm: if installed.contains("npm") { return true }
            case .pnpm: if installed.contains("pnpm") { return true }
            case .bun: if installed.contains("bun") { return true }
            case .macApplication, .standalone: continue
            }
        }
        return false
    }
}
