import SwiftUI

@main
struct OpenDeckApp: App {
    @StateObject private var model = DeckModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if model.connected {
                    StreamView(model: model)
                } else {
                    ConnectView(model: model)
                }
            }
            .preferredColorScheme(.dark)
            .onOpenURL { model.handleOpenURL($0) }
        }
    }
}
