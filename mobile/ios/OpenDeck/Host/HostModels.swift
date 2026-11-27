import Foundation

/// `GET /ports` row — a listening TCP socket or bound UDP endpoint on the
/// desktop host (server `hostinfo.rs`).
struct PortEntry: Decodable, Identifiable, Hashable {
    var id: String { "\(protocolType):\(address):\(port):\(pid)" }

    var protocolType: String
    var address: String
    var port: Int
    var state: String
    var pid: Int
    var process: String

    enum CodingKeys: String, CodingKey {
        case protocolType = "protocol"
        case address, port, state, pid, process
    }

    var endpoint: String {
        "\(address == "*" ? "0.0.0.0" : address):\(port)"
    }

    func matches(_ query: String) -> Bool {
        let q = query.lowercased()
        return process.lowercased().contains(q)
            || address.lowercased().contains(q)
            || String(port).contains(q)
            || String(pid).contains(q)
            || protocolType.lowercased().contains(q)
    }
}

/// `GET /apps` row — a running process on the desktop host.
struct AppEntry: Decodable, Identifiable, Hashable {
    var id: Int { pid }

    var pid: Int
    var name: String
    var cpuPercent: Double
    var memBytes: UInt64

    enum CodingKeys: String, CodingKey {
        case pid, name
        case cpuPercent = "cpu_percent"
        case memBytes = "mem_bytes"
    }

    func matches(_ query: String) -> Bool {
        let q = query.lowercased()
        return name.lowercased().contains(q)
            || String(pid).contains(q)
    }
}

/// Thin client for the server's host-introspection HTTP endpoints.
/// Base URL is derived from the connect form's host/port.
struct HostAPI {
    let base: URL

    init?(host: String, port: String) {
        var h = host.trimmingCharacters(in: .whitespaces)
        if h.isEmpty { return nil }
        // Accept bare IPs/hostnames; strip any scheme the user pasted.
        if h.contains("://") {
            guard let u = URL(string: h) else { return nil }
            h = u.host ?? ""
        }
        let p = port.trimmingCharacters(in: .whitespaces).isEmpty ? "47821" : port
        guard let url = URL(string: "http://\(h):\(p)") else { return nil }
        base = url
    }

    func ports() async throws -> [PortEntry] {
        try await get("ports")
    }

    func apps() async throws -> [AppEntry] {
        try await get("apps")
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let (data, resp) = try await URLSession.shared.data(from: base.appendingPathComponent(path))
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
