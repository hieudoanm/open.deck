import SwiftUI

/// NFC tools — counterpart of Android's `NfcScreen`. iOS scans are
/// user-initiated `NFCTagReaderSession`s (no ambient dispatch), so "Scan"
/// and "Write" buttons each present the system scanning UI.
struct NfcView: View {
    @ObservedObject var model: DeckModel
    @State private var showHistory = false
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("← Back") { model.closeNfc() }
                Spacer()
                Text("NFC Tools")
                    .font(.headline)
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                .font(.body)
            }

            if model.nfcBusy {
                ProgressView()
            }
            if let message = model.nfcMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Color(red: 0.54, green: 0.98, blue: 0.8))
            }

            if let info = model.nfcInfo {
                tagCard(info)
            }

            Spacer()

            if !NfcService.isAvailable {
                Text("NFC is not available on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            TextField("Text record", text: $model.writeText)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("https://example.com", text: $model.writeURI)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled()

            Button {
                Task { await model.writeNfc() }
            } label: {
                Text("Write")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.nfcBusy || composerRecords.isEmpty)

            Button {
                Task { await model.scanNfc() }
            } label: {
                Text("Scan")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(model.nfcBusy)

            Text("Reading works for any NDEF tag; writing needs a writable NDEF tag.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .sheet(isPresented: $showHistory) {
            HistoryView(store: model.history)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: model.settings)
        }
    }

    /// Records the composer would write — omni `composerRecords` parity.
    private var composerRecords: [NdefRecord] {
        var records: [NdefRecord] = []
        let text = model.writeText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { records.append(.text(text, languageCode: "en")) }
        let uri = model.writeURI.trimmingCharacters(in: .whitespacesAndNewlines)
        if !uri.isEmpty { records.append(.uri(uri)) }
        return records
    }

    private func tagCard(_ info: TagInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !info.uid.isEmpty {
                infoRow("UID", info.uid, monospaced: true)
            }
            infoRow("Technologies", info.techList.joined(separator: ", "))
            infoRow("Writable", info.isWritable ? "Yes" : "No")
            infoRow("NDEF Formattable", info.isNdefFormattable ? "Yes" : "No")
            if info.maxSize > 0 {
                infoRow("Max NDEF Size", "\(info.maxSize) bytes")
                infoRow("Used Size", "\(info.usedSize) bytes")
            }
            if !info.ndefRecords.isEmpty {
                Text("NDEF Records")
                    .font(.caption.bold())
                ForEach(Array(info.ndefRecords.enumerated()), id: \.offset) { index, record in
                    recordCard(index: index, record: record)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(white: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func infoRow(_ label: String, _ value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(monospaced ? .caption.monospaced() : .caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    /// Structured per-record card — omni `recordCard` parity.
    private func recordCard(index: Int, record: NdefRecord) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            switch record {
            case let .text(text, languageCode):
                infoRow("Record \(index)", "Text")
                infoRow("Language", languageCode)
                infoRow("Content", text)
            case let .uri(uri):
                infoRow("Record \(index)", "URI")
                infoRow("URL", uri)
            case let .mime(mimeType, payload):
                infoRow("Record \(index)", "MIME")
                infoRow("Type", mimeType)
                infoRow("Payload", "\(payload.count) bytes")
            case let .aar(packageName):
                infoRow("Record \(index)", "App Launch")
                infoRow("Package", packageName)
            case let .unknown(tnf, _, _):
                infoRow("Record \(index)", "Unknown (TNF: \(tnf))")
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.16))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
