import SwiftUI

struct HarnessDetailView: View {
    @Environment(AppState.self) private var appState
    let snapshot: HarnessSnapshot

    private var definition: HarnessDefinition? {
        HarnessRegistry.definition(for: snapshot.definitionId)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                Divider()
                facts
                if !snapshot.configItems.isEmpty {
                    Divider()
                    configSection
                }
                Divider()
                actions
                if let notes = definition?.notes {
                    Divider()
                    Text(notes)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .background(.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: definition?.iconName ?? "app")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(snapshot.name)
                    .font(.title2.weight(.semibold))
                Spacer()
                StatusBadge(status: snapshot.status)
            }
            if let website = definition?.website {
                Link(website.host ?? website.absoluteString, destination: website)
                    .font(.caption)
            }
        }
    }

    private var facts: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 10) {
            fact("Status", snapshot.status.displayName)
            fact("Version", snapshot.displayVersion)
            if let latest = snapshot.latestVersion {
                fact("Latest", latest)
            }
            fact("Location", snapshot.binaryPath ?? snapshot.applicationPath ?? "—")
            fact("Installed Through", snapshot.displayInstallMethod)
            fact("Provider", snapshot.displayProvider)
            fact("Processes", "\(snapshot.processCount)")
            fact("Active Project", snapshot.displayActiveProject)
        }
    }

    private func fact(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
                .font(title == "Location" || title == "Version" || title == "Latest" ? .body.monospaced() : .body)
        }
    }

    private var configSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Configuration")
                .font(.headline)
            ForEach(snapshot.configItems) { item in
                HStack {
                    Image(systemName: item.exists ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.exists ? .green : .secondary)
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.label)
                        Text(item.path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    if item.exists {
                        Button("Reveal") { appState.revealPath(item.path) }
                            .buttonStyle(.borderless)
                    }
                }
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Actions")
                .font(.headline)
            HStack(spacing: 8) {
                Button("Open") { appState.openHarness(snapshot) }
                Button("Launch in Project…") {
                    appState.projectPickerHarness = snapshot
                }
                if snapshot.updateStatus == .updateAvailable {
                    Button("Update") {
                        Task { await appState.requestUpdate(for: snapshot) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            HStack(spacing: 8) {
                if let path = snapshot.binaryPath {
                    Button("Reveal Binary") { appState.revealPath(path) }
                    Button("Copy Path") { appState.copyToPasteboard(path) }
                }
                if let config = snapshot.configItems.first(where: \.exists) {
                    Button("Reveal Config") { appState.revealPath(config.path) }
                }
                Button("Run Diagnostics") { appState.runDiagnostics(for: snapshot) }
            }
        }
    }
}
