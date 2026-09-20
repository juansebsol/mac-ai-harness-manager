import AppKit
import SwiftUI

struct ProvidersView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                PageHeading(eyebrow: "CONNECTIONS", title: "Know your setup.", subtitle: "Provider signals, detected locally. Your keys stay on your Mac.")
                VStack(spacing: 0) {
                    ForEach(appState.providers) { item in
                        HStack(spacing: 16) {
                            Image(systemName: "key.horizontal").font(.title3).frame(width: 44, height: 44)
                                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.name).font(.system(size: 14, weight: .semibold))
                                Text(item.detectedSignals.isEmpty ? "No local configuration found" : item.detectedSignals.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Text(item.configurationLabel).font(.caption.weight(.medium))
                                .foregroundStyle(item.isConfigured ? Color.primary : .secondary)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.primary.opacity(0.05), in: Capsule())
                        }.padding(18)
                        if item.id != appState.providers.last?.id { Divider().padding(.leading, 78) }
                    }
                }.background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
                Text("Configuration signals indicate a local setup. They do not verify API access or account balance.").font(.caption).foregroundStyle(.secondary)
            }.padding(28)
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
