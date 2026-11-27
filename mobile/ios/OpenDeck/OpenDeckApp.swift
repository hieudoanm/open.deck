import SwiftUI

@main
struct OpenDeckApp: App {
    @StateObject private var model = DeckModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if model.showNfc {
                    NfcView(model: model)
                } else if model.connected {
                    StreamView(model: model)
                } else {
                    ConnectView(model: model)
                }
            }
            .preferredColorScheme(.dark)
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
