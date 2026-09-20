import SwiftUI

struct RootView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(AppState.self) private var appState
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        Group {
            if !settingsStore.settings.hasCompletedOnboarding {
                OnboardingView()
            } else {
                MainSplitView()
            }
        }
        .onAppear { updateStatusItem() }
        .onChange(of: settingsStore.settings.showMenuBarExtra) { _, _ in updateStatusItem() }
        .alert("Action unavailable", isPresented: Binding(get: { appState.actionError != nil }, set: { if !$0 { appState.actionError = nil } })) {
            Button("OK") { appState.actionError = nil }
        } message: { Text(appState.actionError ?? "") }
        .sheet(item: Bindable(appState).updateConfirmation) { confirmation in
            UpdateConfirmationSheet(confirmation: confirmation)
        }
        .sheet(item: Bindable(appState).executionSheet) { _ in
            ExecutionOutputSheet()
        }
        .sheet(item: Bindable(appState).diagnosticsSheet) { _ in
            DiagnosticsSheet()
        }
        .sheet(item: Bindable(appState).launchSheet) { sheet in
            LaunchInProjectSheet(project: sheet.project)
        }
        .sheet(item: Bindable(appState).projectPickerHarness) { harness in
            ProjectPickerSheet(harness: harness)
        }
    }

    private func updateStatusItem() {
        HarnessStatusItem.shared.configure(visible: settingsStore.settings.showMenuBarExtra) {
            openWindow(id: "main")
        }
    }

}

struct MainSplitView: View {
    @Environment(AppState.self) private var appState

    private var inspectorPresented: Binding<Bool> {
        Binding(
            get: { appState.isInspectorPresented },
            set: { presented in
                if !presented {
                    appState.closeInspector()
                }
            }
        )
    }

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            ContentRouterView()
                .navigationSplitViewColumnWidth(min: 560, ideal: 720)
        }
        .navigationSplitViewStyle(.balanced)
        .inspector(isPresented: inspectorPresented) {
            InspectorCardView()
                .inspectorColumnWidth(min: 300, ideal: 360, max: 440)
        }
        .onChange(of: appState.selectedSidebar) { _, newValue in
            // Inspector only applies to harness-related screens.
            if ![.allHarnesses, .running, .problems, .store].contains(newValue) {
                appState.closeInspector()
            }
        }
    }
}

struct ContentRouterView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        switch appState.selectedSidebar {
        case .allHarnesses, .running, .problems:
            HarnessesListView()
        case .store:
            StoreView()
        case .news:
            HarnessNewsView()
        case .providers:
            ProvidersView()
        case .mcpServers:
            MCPServersView()
        case .skills:
            SkillsView()
        case .processes:
            ProcessesView()
        case .settings:
            SettingsView()
        case .about:
            AboutView()
        }
    }
}

struct InspectorCardView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let harness = appState.selectedHarness {
                HarnessDetailView(snapshot: harness)
            } else {
                ContentUnavailableView {
                    Label("Inspector", systemImage: "sidebar.right")
                } description: {
                    Text("Select a harness to inspect details.")
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button {
                    appState.closeInspector()
                } label: {
                    Image(systemName: "xmark")
                }
                .help("Close Inspector")
            }
        }
    }
}
