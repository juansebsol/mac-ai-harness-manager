import SwiftUI

@main
struct HarnessManagerApp: App {
    @State private var settingsStore: SettingsStore
    @State private var appState: AppState

    init() {
        let store = SettingsStore()
        _settingsStore = State(initialValue: store)
        _appState = State(initialValue: AppState(settingsStore: store))
    }

    var body: some Scene {
        // Intentionally minimal Scene graph.
        // Extra scenes (MenuBarExtra / CommandMenu observing @Observable state)
        // caused an infinite main-menu invalidation loop (100% CPU / beach ball).
        WindowGroup("Harness Manager") {
            RootView()
                .environment(appState)
                .environment(settingsStore)
                .frame(minWidth: 980, minHeight: 640)
                .task {
                    appState.start()
                }
        }
        .defaultSize(width: 1100, height: 720)
    }
}
