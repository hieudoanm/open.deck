import Foundation
import UIKit

struct HelloInfo {
    var desktopWidth: Int
    var desktopHeight: Int
    var streamWidth: Int
    var streamHeight: Int
}

/// Per-interface throughput inside `DesktopStats.netInterfaces`.
struct NetInterfaceStat {
    var name: String
    var rxRate: UInt64
    var txRate: UInt64
}

/// Host stats pushed by the server every ~2s (`{"type":"stats",...}`).
struct DesktopStats {
    var cpuPercent: Double
    var memUsed: UInt64
    var memTotal: UInt64
    var swapUsed: UInt64
    var swapTotal: UInt64
    var diskUsed: UInt64
    var diskTotal: UInt64
    var netRxRate: UInt64
    var netTxRate: UInt64
    var netInterfaces: [NetInterfaceStat]
    var uptimeSecs: UInt64
    var batteryPercent: Double?
    var batteryState: String?
    var memoryPressure: Double?
}

/// Thin wrapper around URLSessionWebSocketTask speaking the OpenDeck
/// protocol (see docs/PROTOCOL.md). Runs its receive loop on a dedicated
/// URLSession delegate queue.
final class DeckClient {
    var onFrame: ((UIImage) -> Void)?
    var onHello: ((HelloInfo) -> Void)?
    var onStats: ((DesktopStats) -> Void)?
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
        case "stats":
            let interfaces = (obj["net_interfaces"] as? [[String: Any]] ?? []).map { i in
                NetInterfaceStat(
                    name: i["name"] as? String ?? "",
                    rxRate: uint64(i["rx_rate"]),
                    txRate: uint64(i["tx_rate"])
                )
            }
            let stats = DesktopStats(
                cpuPercent: obj["cpu_percent"] as? Double ?? 0,
                memUsed: uint64(obj["mem_used"]),
                memTotal: uint64(obj["mem_total"]),
                swapUsed: uint64(obj["swap_used"]),
                swapTotal: uint64(obj["swap_total"]),
                diskUsed: uint64(obj["disk_used"]),
                diskTotal: uint64(obj["disk_total"]),
                netRxRate: uint64(obj["net_rx_rate"]),
                netTxRate: uint64(obj["net_tx_rate"]),
                netInterfaces: interfaces,
                uptimeSecs: uint64(obj["uptime_secs"]),
                batteryPercent: obj["battery_percent"] as? Double,
                batteryState: obj["battery_state"] as? String,
                memoryPressure: obj["memory_pressure"] as? Double
            )
            DispatchQueue.main.async { self.onStats?(stats) }
        case "pong":
            break
        case "error":
            let message = obj["message"] as? String ?? "server error"
            DispatchQueue.main.async { self.onState?(true, message) }
        default:
            break
        }
    }

    private func uint64(_ value: Any?) -> UInt64 {
        switch value {
        case let n as Int: return UInt64(max(0, n))
        case let n as Double: return UInt64(max(0, n))
        case let n as NSNumber: return n.uint64Value
        default: return 0
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
