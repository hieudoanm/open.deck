import ApplicationServices
import Combine
import CoreGraphics
import Foundation

/// Locates the `open-deck-server` companion binary.
enum ServerLocator {
    static func find() -> String? {
        var candidates: [String] = []

        if let env = ProcessInfo.processInfo.environment["OPENSDECK_SERVER"], !env.isEmpty {
            candidates.append(env)
        }

        // Same directory as this app's executable (bundled companion).
        if let exeDir = Bundle.main.executableURL?.deletingLastPathComponent().path {
            candidates.append(exeDir + "/open-deck-server")
        }

        // On PATH.
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.split(separator: ":") {
                candidates.append(String(dir) + "/open-deck-server")
            }
        }

        // Repo dev builds: walk up from the working directory looking for
        // server/target/{release,debug}/open-deck-server.
        var dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<6 {
            for profile in ["release", "debug"] {
                candidates.append(dir.appendingPathComponent("server/target/\(profile)/open-deck-server").path)
            }
            dir.deleteLastPathComponent()
        }

        let fm = FileManager.default
        return candidates.first { path in
            fm.isExecutableFile(atPath: path)
        }
    }
}

/// Manages the `open-deck-server` child process: launches it, scrapes the
/// pairing token from its stdout, and polls `/status` for live stats.
@MainActor
final class ServerManager: ObservableObject {
    enum RunState: Equatable {
        case stopped
        case starting
        case running
        case failed(String)
    }

    // MARK: - Published state

    @Published private(set) var state: RunState = .stopped
    @Published private(set) var token: String?
    @Published private(set) var clients: Int = 0
    @Published private(set) var monitorInfo: String?
    @Published private(set) var serverPath: String?
    @Published private(set) var logLines: [String] = []
    @Published private(set) var devices: [DeviceInfo] = []
    @Published private(set) var actions: [ActionInfo] = []

    // MARK: - Settings (persisted)

    @Published var port: Int {
        didSet { UserDefaults.standard.set(port, forKey: "port") }
    }
    @Published var fps: Int {
        didSet { UserDefaults.standard.set(fps, forKey: "fps") }
    }
    @Published var quality: Int {
        didSet { UserDefaults.standard.set(quality, forKey: "quality") }
    }
    @Published var maxWidth: Int {
        didSet { UserDefaults.standard.set(maxWidth, forKey: "maxWidth") }
    }
    @Published var customToken: String {
        didSet { UserDefaults.standard.set(customToken, forKey: "customToken") }
    }

    // MARK: - Internals

    private var process: Process?
    private var statusTimer: Timer?
    private let session = URLSession(configuration: .ephemeral)

    init() {
        let d = UserDefaults.standard
        port = d.object(forKey: "port") as? Int ?? 47821
        fps = d.object(forKey: "fps") as? Int ?? 15
        quality = d.object(forKey: "quality") as? Int ?? 70
        maxWidth = d.object(forKey: "maxWidth") as? Int ?? 1280
        customToken = d.string(forKey: "customToken") ?? ""
        serverPath = ServerLocator.find()
    }

    var isRunning: Bool { state == .running || state == .starting }

    /// LAN IPv4 address of this Mac (en0 preferred, else first non-loopback).
    var lanIP: String? { Self.lanIPv4() }

    /// QR payload shared with the Windows/Linux companions:
    /// `opendeck://connect?host=<LAN-IP>&port=<port>&token=<token>`.
    var connectURLString: String? {
        guard let token, let ip = lanIP else { return nil }
        return "opendeck://connect?host=\(ip)&port=\(port)&token=\(token)"
    }

    /// WebSocket URL for manual entry on the phone.
    var wsURLString: String? {
        guard let token, let ip = lanIP else { return nil }
        return "ws://\(ip):\(port)/ws?token=\(token)"
    }

    private static func lanIPv4() -> String? {
        var fallback: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }
        var ptr = ifaddr
        while let cur = ptr {
            let name = String(cString: cur.pointee.ifa_name)
            let family = cur.pointee.ifa_addr.pointee.sa_family
            if family == UInt8(AF_INET) {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(
                    cur.pointee.ifa_addr,
                    socklen_t(cur.pointee.ifa_addr.pointee.sa_len),
                    &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST
                )
                let ip = String(cString: host)
                if ip.hasPrefix("127.") == false {
                    if name == "en0" { return ip }
                    if fallback == nil { fallback = ip }
                }
            }
            ptr = cur.pointee.ifa_next
        }
        return fallback
    }

    // MARK: - Control

    func start() {
        guard process == nil else { return }
        guard let path = serverPath else {
            state = .failed("open-deck-server binary not found. Set OPENSDECK_SERVER or build server/.")
            return
        }

        token = nil
        clients = 0
        state = .starting
        appendLog("Launching \(path)")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = [
            "--port", String(port),
            "--fps", String(fps),
            "--quality", String(quality),
            "--max-width", String(maxWidth),
        ]
        if !customToken.trimmingCharacters(in: .whitespaces).isEmpty {
            proc.arguments?.append(contentsOf: ["--token", customToken.trimmingCharacters(in: .whitespaces)])
        }

        let stdout = Pipe()
        let stderr = Pipe()
        proc.standardOutput = stdout
        proc.standardError = stderr

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            guard let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in self?.handleServerOutput(text) }
        }
        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in self?.appendLog(text.trimmingCharacters(in: .whitespacesAndNewlines)) }
        }

        proc.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                self?.handleTermination(status: proc.terminationStatus)
            }
        }

        do {
            try proc.run()
            process = proc
        } catch {
            state = .failed("Failed to launch: \(error.localizedDescription)")
            appendLog("error: \(error.localizedDescription)")
        }
    }

    func stop() {
        process?.terminate()
    }

    /// Re-scan for the server binary (e.g. after building it).
    func rediscoverServer() {
        serverPath = ServerLocator.find()
    }

    // MARK: - Internals

    private func handleServerOutput(_ chunk: String) {
        for rawLine in chunk.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("Pairing token") {
                token = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Monitor") {
                // "Monitor       : 1920x1080 @ 15fps"
                if let colon = line.firstIndex(of: ":") {
                    let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                    if value.contains("x") { monitorInfo = value }
                }
            } else if line.hasPrefix("WebSocket URL") {
                if let colon = line.firstIndex(of: ":") {
                    let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                    // Server prints a placeholder; substitute the real host/port.
                    _ = value
                }
            }
            // Only surface the banner lines we care about in the log.
            if line.hasPrefix("Pairing token") || line.hasPrefix("Monitor") ||
               line.hasPrefix("WebSocket URL") || line.hasPrefix("===") {
                appendLog(line)
            }
        }
        if state == .starting { state = .running }
        startStatusPolling()
    }

    private func handleTermination(status: Int32) {
        process = nil
        stopStatusPolling()
        clients = 0
        if state != .stopped {
            state = status == 0 ? .stopped : .failed("Server exited with status \(status)")
        }
        appendLog("Server process exited (status \(status))")
    }

    private func startStatusPolling() {
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.pollStatus() }
        }
    }

    private func stopStatusPolling() {
        statusTimer?.invalidate()
        statusTimer = nil
    }

    private func pollStatus() async {
        guard let url = URL(string: "http://127.0.0.1:\(port)/status") else { return }
        do {
            let (data, _) = try await session.data(from: url)
            if let status = try? JSONDecoder().decode(ServerStatus.self, from: data) {
                clients = status.clients
            }
        } catch {
            // Server not up yet or shutting down — ignore.
            return
        }

        if let url = URL(string: "http://127.0.0.1:\(port)/devices"),
           let (data, _) = try? await session.data(from: url),
           let list = try? JSONDecoder().decode([DeviceInfo].self, from: data) {
            devices = list
        }
        if let url = URL(string: "http://127.0.0.1:\(port)/actions"),
           let (data, _) = try? await session.data(from: url),
           let list = try? JSONDecoder().decode([ActionInfo].self, from: data) {
            actions = list
        }
    }

    /// Kick a connected device by its server-side id.
    func disconnectDevice(id: Int) {
        guard let token,
              let url = URL(string: "http://127.0.0.1:\(port)/devices/\(id)/disconnect") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "X-OpenDeck-Token")
        Task { _ = try? await session.data(for: request) }
    }

    /// Run a server-side action (media keys, custom commands).
    func runAction(name: String) {
        guard let token,
              var components = URLComponents(string: "http://127.0.0.1:\(port)/actions/run") else { return }
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        guard let url = components.url else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["name": name])
        Task { _ = try? await session.data(for: request) }
    }

    /// Re-check macOS permissions (Screen Recording / Accessibility).
    func refreshPermissions() {
        screenRecordingGranted = CGPreflightScreenCaptureAccess()
        accessibilityGranted = AXIsProcessTrusted()
    }

    @Published private(set) var screenRecordingGranted = false
    @Published private(set) var accessibilityGranted = false

    private func appendLog(_ line: String) {
        logLines.append(line)
        if logLines.count > 200 { logLines.removeFirst(logLines.count - 200) }
    }
}
