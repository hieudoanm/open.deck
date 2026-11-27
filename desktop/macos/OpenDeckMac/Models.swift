import Foundation

/// Response of the server's `GET /status` endpoint.
struct ServerStatus: Decodable {
    let clients: Int
    let desktop_width: Int
    let desktop_height: Int
    let fps: Int
}

/// One entry of `GET /devices` — a connected phone/remote.
struct DeviceInfo: Decodable, Identifiable {
    let id: Int
    let name: String
    let addr: String
    let connected_at: Int
}

/// One entry of `GET /actions` — a server-side action the desktop can trigger.
struct ActionInfo: Decodable, Identifiable {
    let name: String
    let kind: String
    let detail: String?

    var id: String { name }
}
