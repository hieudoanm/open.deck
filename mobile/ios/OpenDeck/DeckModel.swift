import SwiftUI
import UIKit

@MainActor
final class DeckModel: ObservableObject {
    @Published var host = ""
    @Published var port = "47821"
    @Published var token = ""
    @Published var status = "Not connected"
    @Published var connected = false
    @Published var frame: UIImage?
    @Published var hello: HelloInfo?

    private let client = DeckClient()

    init() {
        client.onFrame = { [weak self] img in
            self?.frame = img
        }
        client.onHello = { [weak self] h in
            self?.hello = h
        }
        client.onState = { [weak self] ok, msg in
            guard let self else { return }
            self.status = msg
            self.connected = ok
            if !ok {
                self.frame = nil
                self.hello = nil
            }
        }
    }

    func connect() {
        let h = host.trimmingCharacters(in: .whitespaces)
        let t = token.trimmingCharacters(in: .whitespaces)
        guard !h.isEmpty, !t.isEmpty else {
            status = "Enter host and token"
            return
        }
        client.connect(urlString: "ws://\(h):\(port)/ws?token=\(t)")
    }

    /// Fill the connect form from an `opendeck://connect?host=…&port=…&token=…`
    /// deep link (the payload encoded in the desktop companions' pairing QR).
    func handleOpenURL(_ url: URL) {
        guard url.scheme == "opendeck", url.host == "connect" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func param(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }
        if let h = param("host"), !h.isEmpty { host = h }
        if let p = param("port"), !p.isEmpty { port = p }
        if let t = param("token"), !t.isEmpty { token = t }
        status = "Pairing details filled — tap Connect"
    }

    func disconnect() {
        client.disconnect()
        connected = false
        frame = nil
        hello = nil
    }

    func mouseMove(x: Int, y: Int) { client.sendMouseMove(x: x, y: y) }
    func mouseButton(_ button: String, state: String) {
        client.sendMouseButton(button, state: state)
    }
    func key(_ key: String) { client.sendKey(key) }
}
