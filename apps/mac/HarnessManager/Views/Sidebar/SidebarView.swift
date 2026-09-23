import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List(selection: Bindable(appState).selectedSidebar) {
            Section("Tools") {
                ForEach(SidebarItem.harnesses) { item in
                    Label(item.title, systemImage: item.systemImage)
                        .tag(item)
                }
            }

            Section("Connections") {
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
        .safeAreaInset(edge: .top) {
            HStack(spacing: 9) {
                Image("HarnessBrand").resizable().scaledToFit().frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Harness Manager").font(.system(size: 12, weight: .semibold))
                    Text("Your AI workspace").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }.padding(.horizontal, 12).padding(.vertical, 18)
        }
        .safeAreaInset(edge: .bottom) {
            if !appState.isScanning && !appState.isEnriching {
                HStack(spacing: 8) {
                    Image(systemName: "desktopcomputer").foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This Mac").font(.caption.weight(.medium))
                        Text("\(appState.summary.installed) tools installed").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }.padding(14)
            } else {
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
