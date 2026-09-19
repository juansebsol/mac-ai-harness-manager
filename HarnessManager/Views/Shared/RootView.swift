import SwiftUI

struct RootView: View {
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
}

struct MainSplitView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } content: {
            ContentRouterView()
                .navigationSplitViewColumnWidth(min: 420, ideal: 560)
        } detail: {
            DetailRouterView()
                .navigationSplitViewColumnWidth(min: 300, ideal: 360)
        }
        .navigationSplitViewStyle(.balanced)
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

struct DetailRouterView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if let harness = appState.selectedHarness,
           [.allHarnesses, .running, .problems, .store].contains(appState.selectedSidebar) {
            HarnessDetailView(snapshot: harness)
        } else {
            ContentUnavailableView {
                Label("Inspector", systemImage: "sidebar.right")
            } description: {
                Text("Select a harness to inspect details, configuration, and actions.")
            }
        }
    }
}
