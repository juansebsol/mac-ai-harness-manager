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
        WindowGroup("Harness Manager", id: "main") {
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


/// AppKit owns this static menu, avoiding SwiftUI scene observation/invalidation loops.
@MainActor
final class HarnessStatusItem: NSObject {
    static let shared = HarnessStatusItem()
    private var item: NSStatusItem?
    private var openDashboard: (() -> Void)?

    func configure(visible: Bool, openDashboard: @escaping () -> Void) {
        self.openDashboard = openDashboard
        guard visible else {
            if let item { NSStatusBar.system.removeStatusItem(item) }
            item = nil
            return
        }
        guard item == nil else { return }
        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let mark = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            let path = NSBezierPath()
            path.lineWidth = 2.2
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: NSPoint(x: 3, y: 16))
            path.line(to: NSPoint(x: 6, y: 16))
            path.line(to: NSPoint(x: 6, y: 2))
            path.line(to: NSPoint(x: 3, y: 2))
            path.move(to: NSPoint(x: 15, y: 16))
            path.line(to: NSPoint(x: 12, y: 16))
            path.line(to: NSPoint(x: 12, y: 2))
            path.line(to: NSPoint(x: 15, y: 2))
            path.move(to: NSPoint(x: 6, y: 9))
            path.line(to: NSPoint(x: 12, y: 9))
            path.stroke()
            return true
        }
        mark.isTemplate = true
        status.button?.image = mark
        status.button?.toolTip = "Harness Manager"
        status.button?.setAccessibilityLabel("Harness Manager")
        let menu = NSMenu()
        let open = NSMenuItem(title: "Open Harness Manager", action: #selector(showDashboard), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Harness Manager", action: #selector(quitApp), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
        status.menu = menu
        item = status
    }

    @objc private func showDashboard() {
        openDashboard?()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() { NSApp.terminate(nil) }
}
