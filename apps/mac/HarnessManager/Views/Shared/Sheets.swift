import SwiftUI

struct UpdateConfirmationSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let confirmation: AppState.UpdateConfirmation

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(confirmation.title)
                .font(.title2.weight(.semibold))

            if confirmation.prerequisiteFormula != nil {
                Text("This tool needs a package manager. We’ll set up Homebrew, then install \(confirmation.harnessName) automatically. Terminal will open for setup and may ask for your Mac password or Apple Command Line Tools.")
                    .font(.callout)
                Link("About the official Homebrew installer", destination: URL(string: "https://brew.sh")!)
            }

            if confirmation.kind == .update {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        Text("Installed").foregroundStyle(.secondary)
                        Text(confirmation.installed ?? "—").font(.body.monospaced())
                    }
                    GridRow {
                        Text("Latest").foregroundStyle(.secondary)
                        Text(confirmation.latest ?? "—").font(.body.monospaced())
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Command")
                    .font(.headline)
                Text(confirmation.displayCommand)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
            }

            Text("This will modify software on your Mac. Nothing runs until you confirm.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                    appState.updateConfirmation = nil
                }
                .keyboardShortcut(.cancelAction)
                Button(confirmation.confirmLabel) {
                    appState.confirmUpdate(confirmation)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}

struct ExecutionOutputSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let state = appState.executionSheet
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(state?.title ?? "Command")
                    .font(.title2.weight(.semibold))
                Spacer()
                if state?.isRunning == true {
                    ProgressView()
                        .controlSize(.small)
                } else if let code = state?.exitCode {
                    Text(code == 0 ? "Succeeded" : "Failed")
                        .foregroundStyle(code == 0 ? Color.green : Color.red)
                        .font(.callout.weight(.medium))
                }
            }

            ScrollView {
                Text((state?.output.isEmpty ?? true) ? "Waiting for output…" : (state?.output ?? ""))
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 240)
            .padding(8)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))

            if let code = state?.exitCode {
                Text("Exit code: \(code)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button(state?.isRunning == true ? "Running…" : "Close") {
                    dismiss()
                    appState.executionSheet = nil
                }
                .disabled(state?.isRunning == true)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560, height: 400)
    }
}

struct DiagnosticsSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let state = appState.diagnosticsSheet
        VStack(alignment: .leading, spacing: 12) {
            Text(state?.harnessName ?? "Diagnostics")
                .font(.title2.weight(.semibold))
            Text("Diagnostics")
                .foregroundStyle(.secondary)

            if state?.isRunning == true {
                HStack {
                    ProgressView()
                    Text("Running checks…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(state?.results ?? []) { result in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: result.severity.symbolName)
                            .foregroundStyle(color(for: result.severity))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.name)
                                .font(.body.weight(.medium))
                            Text(result.message)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                }
                .listStyle(.plain)
            }

            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                    appState.diagnosticsSheet = nil
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520, height: 440)
    }

    private func color(for severity: DiagnosticSeverity) -> Color {
        switch severity {
        case .pass: return .green
        case .warning: return .orange
        case .error: return .red
        case .informational: return .secondary
        }
    }
}

struct LaunchInProjectSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let project: CodingProject

    private var launchable: [HarnessSnapshot] {
        appState.harnesses.filter { $0.isInstalled && $0.binaryPath != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Open With")
                .font(.title2.weight(.semibold))
            Text(project.name)
                .foregroundStyle(.secondary)
            Text(project.path)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)

            Text("Launching opens your preferred terminal with this project as the working directory. Terminal.app Automation permission may be requested to run the harness command.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if launchable.isEmpty {
                Text("No installed harness CLIs detected.")
                    .foregroundStyle(.secondary)
            } else {
                List(launchable) { harness in
                    Button {
                        appState.launchHarness(harness, in: project)
                        dismiss()
                        appState.launchSheet = nil
                    } label: {
                        HStack {
                            Image(systemName: HarnessRegistry.definition(for: harness.definitionId)?.iconName ?? "terminal")
                            Text(harness.name)
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(minHeight: 180)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                    appState.launchSheet = nil
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 420, height: 420)
    }
}

struct ProjectPickerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let harness: HarnessSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Launch \(harness.name) in…")
                .font(.title2.weight(.semibold))
            Text("Choose a project directory for the working directory.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if appState.projects.isEmpty {
                Text("No projects found. Add roots under Settings → Discovery (defaults: ~/Developer, ~/Projects).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
            } else {
                List(appState.projects) { project in
                    Button {
                        appState.launchHarness(harness, in: project)
                        dismiss()
                        appState.projectPickerHarness = nil
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.name)
                            Text(project.path)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(minHeight: 220)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                    appState.projectPickerHarness = nil
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 440, height: 440)
    }
}
