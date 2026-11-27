import SwiftUI

@main
struct OpenDeckApp: App {
    @StateObject private var manager = ServerManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(manager)
                .frame(minWidth: 520, minHeight: 640)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
