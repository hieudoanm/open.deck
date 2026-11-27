import Foundation

/// Response of the server's `GET /status` endpoint.
struct ServerStatus: Decodable {
    let clients: Int
    let desktop_width: Int
    let desktop_height: Int
    let fps: Int
}
