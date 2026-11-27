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

/// Desktop clipboard entry — `GET /clipboard` row (server `clipboard.rs`).
struct ClipboardEntry: Decodable, Identifiable, Hashable {
    var id: UInt64
    var content: String
    var isUrl: Bool
    var createdAt: UInt64
    var copiedCount: UInt32

    enum CodingKeys: String, CodingKey {
        case id, content
        case isUrl = "is_url"
        case createdAt = "created_at"
        case copiedCount = "copied_count"
    }
}

/// Thin client for the server's host-introspection HTTP endpoints.
/// Base URL is derived from the connect form's host/port; `token` is the
/// pairing token required by the destructive/sensitive routes.
struct HostAPI {
    let base: URL
    var token: String

    init?(host: String, port: String, token: String = "") {
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
        self.token = token.trimmingCharacters(in: .whitespaces)
    }

    func ports() async throws -> [PortEntry] {
        try await get("ports")
    }

    func apps() async throws -> [AppEntry] {
        try await get("apps")
    }

    /// `POST /ports/kill` — SIGTERM, or SIGKILL when `force`.
    func killPort(pid: Int, force: Bool = false) async throws {
        var comps = URLComponents(url: base.appendingPathComponent("ports/kill"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "token", value: token)]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["pid": pid, "force": force])
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    /// `GET /clipboard` — desktop clipboard history.
    func clipboard() async throws -> [ClipboardEntry] {
        try await get("clipboard")
    }

    /// `POST /clipboard` — write text to the desktop clipboard + record it.
    func clipboardWrite(_ content: String) async throws {
        var comps = URLComponents(url: base.appendingPathComponent("clipboard"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "token", value: token)]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["content": content])
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    /// `DELETE /clipboard` — clear desktop clipboard history.
    func clipboardClear() async throws {
        var comps = URLComponents(url: base.appendingPathComponent("clipboard"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "token", value: token)]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "DELETE"
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        var comps = URLComponents(
            url: base.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        comps.queryItems = [URLQueryItem(name: "token", value: token)]
        let (data, resp) = try await URLSession.shared.data(from: comps.url!)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
