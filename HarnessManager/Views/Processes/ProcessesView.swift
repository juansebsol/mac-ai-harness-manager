import AppKit
import SwiftUI

struct ProcessesView: View {
    @Environment(AppState.self) private var appState
    @State private var forceQuitTarget: DetectedProcess?

    var body: some View {
        Group {
            if appState.processes.isEmpty {
                ContentUnavailableView {
                    Label("No harness processes running", systemImage: "cpu")
                } description: {
                    Text("Running AI coding harness processes will appear here.")
                }
            } else {
                Table(appState.processes) {
                    TableColumn("Process") { item in
                        Text(item.executableName)
                            .font(.body.monospaced())
                    }
                    TableColumn("Harness") { item in
                        Text(item.harnessName ?? "—")
                    }
                    TableColumn("PID") { item in
                        Text("\(item.pid)")
                            .font(.body.monospaced())
                    }
                    TableColumn("CPU") { item in
                        Text(item.displayCPU)
                            .monospacedDigit()
                    }
                    TableColumn("Memory") { item in
                        Text(item.displayMemory)
                            .monospacedDigit()
                    }
                    TableColumn("Runtime") { item in
                        Text(item.displayRuntime)
                    }
                    TableColumn("Working Directory") { item in
                        Text(item.workingDirectory ?? "—")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    TableColumn("Project") { item in
                        Text(item.projectName ?? "—")
                    }
                }
                .contextMenu(forSelectionType: DetectedProcess.ID.self) { ids in
                    if let id = ids.first, let process = appState.processes.first(where: { $0.id == id }) {
                        if let cwd = process.workingDirectory {
                            Button("Reveal Project") { appState.revealPath(cwd) }
                        }
                        Button("Copy PID") { appState.copyToPasteboard("\(process.pid)") }
                        Divider()
                        Button("Terminate") { appState.terminateProcess(process, force: false) }
                        Button("Force Quit…", role: .destructive) { forceQuitTarget = process }
                    }
                }
            }
        }
        .navigationTitle("Processes")
        .toolbar {
            Button {
                Task { await appState.fullRefresh(checkUpdates: false) }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .confirmationDialog(
            "Force quit process?",
            isPresented: Binding(
                get: { forceQuitTarget != nil },
                set: { if !$0 { forceQuitTarget = nil } }
            ),
            presenting: forceQuitTarget
        ) { process in
            Button("Force Quit", role: .destructive) {
                appState.terminateProcess(process, force: true)
                forceQuitTarget = nil
            }
            Button("Cancel", role: .cancel) { forceQuitTarget = nil }
        } message: { process in
            Text("Send SIGKILL to \(process.executableName) (PID \(process.pid))? This cannot be undone.")
        }
    }
}

