import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List(selection: Bindable(appState).selectedSidebar) {
            Section("Harnesses") {
                ForEach(SidebarItem.harnesses) { item in
                    Label(item.title, systemImage: item.systemImage)
                        .tag(item)
                }
            }

            Section("Infrastructure") {
                ForEach(SidebarItem.infrastructure) { item in
                    Label(item.title, systemImage: item.systemImage)
                        .tag(item)
                }
            }

            Section("System") {
                ForEach(SidebarItem.system) { item in
                    Label(item.title, systemImage: item.systemImage)
                        .tag(item)
                }
            }

            Section {
                ForEach(SidebarItem.bottom) { item in
                    Label(item.title, systemImage: item.systemImage)
                        .tag(item)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            if appState.isScanning || appState.isEnriching {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(appState.isScanning ? "Scanning…" : "Updating details…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(10)
            }
        }
    }
}
