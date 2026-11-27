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

    // NFC tool state (parity with Android's DeckViewModel)
    @Published var showNfc = false
    @Published var nfcInfo: TagInfo?
    @Published var nfcMessage: String?
    @Published var nfcBusy = false
    @Published var writeAsUri = true
    @Published var writeValue = ""

    let nfcService = NfcService()

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

    func openNfc() {
        if nfcMessage == nil {
            nfcMessage = "Tap Scan, then hold your iPhone near a tag"
        }
        showNfc = true
    }

    func closeNfc() {
        showNfc = false
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
            if let uri = Self.connectURI(in: info), let url = URL(string: uri) {
                handleOpenURL(url)
                showNfc = false
                nfcMessage = "Pairing details filled — tap Connect"
            } else {
                nfcInfo = info
                nfcMessage = nil
            }
        } catch {
            nfcBusy = false
            nfcMessage = (error as? NfcError) == .cancelled ? nil : error.localizedDescription
        }
    }

    /// Write the composed URI/text record, then present the write session.
    func writeNfc() async {
        let value = writeValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            nfcMessage = "Enter a value first"
            return
        }
        let record: NdefRecord = writeAsUri ? .uri(value) : .text(value, languageCode: "en")
        nfcBusy = true
        nfcMessage = "Writing…"
        do {
            try await nfcService.writeTag([record])
            nfcBusy = false
            nfcMessage = "Wrote '\(value)' to tag"
            writeValue = ""
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
