import Foundation
import UIKit

struct HelloInfo {
    var desktopWidth: Int
    var desktopHeight: Int
    var streamWidth: Int
    var streamHeight: Int
}

/// Thin wrapper around URLSessionWebSocketTask speaking the OpenDeck
/// protocol (see docs/PROTOCOL.md). Runs its receive loop on a dedicated
/// URLSession delegate queue.
final class DeckClient {
    var onFrame: ((UIImage) -> Void)?
    var onHello: ((HelloInfo) -> Void)?
    var onState: ((Bool, String) -> Void)?

    private var task: URLSessionWebSocketTask?
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    func connect(urlString: String) {
        disconnect()
        guard let url = URL(string: urlString) else {
            onState?(false, "Invalid URL")
            return
        }
        onState?(false, "Connecting…")
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
        receiveLoop(task)
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func receiveLoop(_ task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    self.onState?(false, "Connection failed: \(error.localizedDescription)")
                }
            case .success(let message):
                switch message {
                case .data(let data):
                    if let img = UIImage(data: data) {
                        DispatchQueue.main.async { self.onFrame?(img) }
                    }
                case .string(let text):
                    self.handleText(text)
                @unknown default:
                    break
                }
                self.receiveLoop(task)
            }
        }
    }

    private func handleText(_ text: String) {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else { return }
        switch type {
        case "hello":
            let hello = HelloInfo(
                desktopWidth: obj["desktop_width"] as? Int ?? 0,
                desktopHeight: obj["desktop_height"] as? Int ?? 0,
                streamWidth: obj["stream_width"] as? Int ?? 0,
                streamHeight: obj["stream_height"] as? Int ?? 0
            )
            DispatchQueue.main.async { self.onHello?(hello) }
            DispatchQueue.main.async { self.onState?(true, "Connected") }
        case "pong":
            break
        case "error":
            let message = obj["message"] as? String ?? "server error"
            DispatchQueue.main.async { self.onState?(true, message) }
        default:
            break
        }
    }

    func send(_ json: String) {
        task?.send(.string(json)) { _ in }
    }

    func sendMouseMove(x: Int, y: Int) {
        send(#"{"type":"mouse_move","x":\#(x),"y":\#(y)}"#)
    }

    func sendMouseButton(_ button: String, state: String) {
        send(#"{"type":"mouse_button","button":"\#(button)","state":"\#(state)"}"#)
    }

    func sendKey(_ key: String, state: String = "press") {
        let escaped = key
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        send(#"{"type":"key","key":"\#(escaped)","state":"\#(state)"}"#)
    }
}
