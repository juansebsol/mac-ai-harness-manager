import AppKit
import SwiftUI

struct ProvidersView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Table(appState.providers) {
            TableColumn("Provider") { item in
                Text(item.name)
            }
            TableColumn("Configuration") { item in
                Text(item.configurationLabel)
                    .foregroundStyle(item.isConfigured ? Color.primary : Color.secondary)
            }
            TableColumn("Signals") { item in
                Text(item.detectedSignals.isEmpty ? "—" : item.detectedSignals.joined(separator: "; "))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            TableColumn("Harnesses") { item in
                let names = item.harnessIds.compactMap { id in
                    appState.harnesses.first(where: { $0.definitionId == id })?.name
                }
                Text(names.isEmpty ? "—" : names.joined(separator: ", "))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Providers")
        .overlay {
            if appState.providers.isEmpty && appState.isScanning {
                ProgressView("Detecting providers…")
            }
        }
    }
}

struct MCPServersView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.mcpServers.isEmpty {
                ContentUnavailableView {
                    Label("No MCP servers discovered", systemImage: "server.rack")
                } description: {
                    Text("MCP configs are discovered read-only from supported harness configuration files.")
                }
            } else {
                Table(appState.mcpServers) {
                    TableColumn("MCP Server", value: \.name)
                    TableColumn("Status") { item in
                        Text(item.status.displayName)
                    }
                    TableColumn("Transport") { item in
                        Text(item.transport.displayName)
                            .foregroundStyle(.secondary)
                    }
                    TableColumn("Harnesses") { item in
                        Text(item.sourceHarnesses.joined(separator: ", "))
                            .foregroundStyle(.secondary)
                    }
                    TableColumn("Configuration") { item in
                        Text(item.configPath ?? "—")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .contextMenu(forSelectionType: MCPServer.ID.self) { _ in } primaryAction: { ids in
                    if let id = ids.first,
                       let server = appState.mcpServers.first(where: { $0.id == id }),
                       let path = server.configPath {
                        appState.revealPath(path)
                    }
                }
            }
        }
        .navigationTitle("MCP Servers")
    }
}

struct SkillsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.skills.isEmpty {
                ContentUnavailableView {
                    Label("No skills discovered", systemImage: "books.vertical")
                } description: {
                    Text("Skills and agent instruction files will appear here when found.")
                }
            } else {
                Table(appState.skills) {
                    TableColumn("Skill", value: \.name)
                    TableColumn("Source", value: \.source)
                    TableColumn("Harness") { item in
                        Text(item.harnessName ?? "—")
                            .foregroundStyle(.secondary)
                    }
                    TableColumn("Scope") { item in
                        Text(item.scope.displayName)
                    }
                    TableColumn("Location") { item in
                        Text(item.location)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .contextMenu(forSelectionType: SkillItem.ID.self) { ids in
                    if let id = ids.first, let skill = appState.skills.first(where: { $0.id == id }) {
                        Button("Reveal") { appState.revealPath(skill.location) }
                        Button("Open File") { NSWorkspace.shared.open(URL(fileURLWithPath: skill.location)) }
                        Button("Copy Path") { appState.copyToPasteboard(skill.location) }
                    }
                }
            }
        }
        .navigationTitle("Skills")
    }
}
