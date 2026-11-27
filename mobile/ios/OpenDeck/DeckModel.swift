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
    @Published var desktopStats: DesktopStats?

    // Dashboard page state — the phone lies horizontally and pages are
    // swiped left/right (parity with Android's DeckViewModel.page).
    @Published var page: DeckPage = .deck

    // NFC tool state (parity with Android's DeckViewModel)
    @Published var nfcInfo: TagInfo?
    @Published var nfcMessage: String?
    @Published var nfcBusy = false
    // Write composer — omni NfcHomeView parity: independent text + URI
    // fields, both optional, composed into one NDEF message.
    @Published var writeText = ""
    @Published var writeURI = ""

    let nfcService = NfcService()
    let settings = SettingsStore()
    let history = TagHistoryStore()

    private let client = DeckClient()

    init() {
        client.onFrame = { [weak self] img in
            self?.frame = img
        }
        client.onHello = { [weak self] h in
            self?.hello = h
        }
        client.onStats = { [weak self] s in
            self?.desktopStats = s
        }
        client.onState = { [weak self] ok, msg in
            guard let self else { return }
            self.status = msg
            self.connected = ok
            if !ok {
                self.frame = nil
                self.hello = nil
                self.desktopStats = nil
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

    // MARK: - NFC tools

    /// First `opendeck://connect` URI record on the tag, if any — the same
    /// payload the desktop QR encodes (parity with Android's connectUri).
    private static func connectURI(in info: TagInfo) -> String? {
        for record in info.ndefRecords {
            if case let .uri(uri) = record, uri.hasPrefix("opendeck://connect") {
                return uri
            }
        }
        return nil
    }

    /// First web URL on the tag — used by the "auto-open URLs" setting
    /// (omni/Android `auto_open_url` parity).
    private static func firstOpenableURL(in info: TagInfo) -> URL? {
        for record in info.ndefRecords {
            if case let .uri(uri) = record,
               uri.hasPrefix("http://") || uri.hasPrefix("https://"),
               let url = URL(string: uri)
            {
                return url
            }
        }
        return nil
    }

    func openNfc() {
        if nfcMessage == nil {
            nfcMessage = "Tap Scan, then hold your iPhone near a tag"
        }
        page = .nfc
    }

    func closeNfc() {
        page = .deck
        nfcInfo = nil
        nfcMessage = nil
    }

    /// User-initiated read scan (iOS has no ambient tag dispatch).
    func scanNfc() async {
        guard !nfcBusy else { return }
        nfcBusy = true
        nfcMessage = "Scanning…"
        do {
            let info = try await nfcService.readTag()
            nfcBusy = false
            history.record(info)
            if let uri = Self.connectURI(in: info), let url = URL(string: uri) {
                handleOpenURL(url)
                page = .deck
                nfcMessage = "Pairing details filled — tap Connect"
            } else {
                nfcInfo = info
                nfcMessage = nil
                if settings.autoOpenUrl, let url = Self.firstOpenableURL(in: info) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        } catch {
            nfcBusy = false
            nfcMessage = (error as? NfcError) == .cancelled ? nil : error.localizedDescription
        }
    }

    /// Compose text/URI records and write them, then present the write
    /// session (omni `composerRecords`/`writeToTag` parity).
    func writeNfc() async {
        var records: [NdefRecord] = []
        let text = writeText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { records.append(.text(text, languageCode: "en")) }
        let uri = writeURI.trimmingCharacters(in: .whitespacesAndNewlines)
        if !uri.isEmpty { records.append(.uri(uri)) }
        guard !records.isEmpty else {
            nfcMessage = "Enter a text or URI value first"
            return
        }
        nfcBusy = true
        nfcMessage = "Writing…"
        do {
            try await nfcService.writeTag(records)
            nfcBusy = false
            nfcMessage = "Wrote \(records.count) record(s) to tag"
            writeText = ""
            writeURI = ""
        } catch {
            nfcBusy = false
            nfcMessage = (error as? NfcError) == .cancelled ? nil : error.localizedDescription
        }
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
