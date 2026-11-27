import SwiftUI

@main
struct OpenDeckApp: App {
    @StateObject private var model = DeckModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            DeckPagerView(model: model)
                .preferredColorScheme(model.settings.darkMode ? .dark : nil)
                .onOpenURL { model.handleOpenURL($0) }
                // Auto-disconnect on exit — parity with Android's onStop hook.
                .onChange(of: scenePhase) { phase in
                    if phase == .background, model.connected {
                        model.disconnect()
                    }
                }
        }
    }
}
