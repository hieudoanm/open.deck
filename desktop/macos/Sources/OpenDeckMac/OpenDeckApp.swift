import AppKit
import SwiftUI

@main
struct OpenDeckApp: App {
    @StateObject private var manager = ServerManager()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(manager)
                .frame(minWidth: 520, minHeight: 640)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        // Background companion: menu-bar presence while the server runs.
        MenuBarExtra("OpenDeck", systemImage: manager.isRunning ? "gamecontroller.fill" : "gamecontroller") {
            MenuBarContent(manager: manager, openWindow: openWindow)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarContent: View {
    @ObservedObject var manager: ServerManager
    let openWindow: OpenWindowAction

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(manager.isRunning ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)
                Text(manager.isRunning ? "Server running" : "Server stopped")
                    .font(.callout.weight(.medium))
            }
            if let token = manager.token {
                Text("Token: \(token)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Divider()
            Button("Show Window") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            Button(manager.isRunning ? "Stop Server" : "Start Server") {
                manager.isRunning ? manager.stop() : manager.start()
            }
            Divider()
            Button("Quit OpenDeck") { NSApplication.shared.terminate(nil) }
        }
        .padding(12)
        .frame(width: 240)
    }
}
