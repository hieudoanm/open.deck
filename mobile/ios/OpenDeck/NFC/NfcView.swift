import SwiftUI

/// NFC tools — counterpart of Android's `NfcScreen`. iOS scans are
/// user-initiated `NFCTagReaderSession`s (no ambient dispatch), so "Scan"
/// and "Write" buttons each present the system scanning UI.
struct NfcView: View {
    @ObservedObject var model: DeckModel

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("← Back") { model.closeNfc() }
                Spacer()
                Text("NFC Tools")
                    .font(.headline)
                Spacer()
                Text("").frame(width: 60)
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

            Picker("Record type", selection: $model.writeAsUri) {
                Text("URI").tag(true)
                Text("Text").tag(false)
            }
            .pickerStyle(.segmented)

            TextField(
                model.writeAsUri ? "URI (e.g. https://…)" : "Text",
                text: $model.writeValue
            )
            .textFieldStyle(.roundedBorder)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            HStack(spacing: 12) {
                Button {
                    Task { await model.writeNfc() }
                } label: {
                    Text("Write")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.nfcBusy || model.writeValue.trimmingCharacters(in: .whitespaces).isEmpty)

                Button {
                    Task { await model.scanNfc() }
                } label: {
                    Text("Scan")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(model.nfcBusy)
            }

            Text("Reading works for any NDEF tag; writing needs a writable NDEF tag.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }

    private func tagCard(_ info: TagInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !info.uid.isEmpty {
                Text("UID: \(info.uid)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Text(info.techList.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
            if !info.ndefRecords.isEmpty {
                Text("Records")
                    .font(.caption.bold())
                ForEach(Array(info.ndefRecords.enumerated()), id: \.offset) { _, record in
                    Text("• \(describe(record))")
                        .font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(white: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func describe(_ record: NdefRecord) -> String {
        switch record {
        case let .uri(uri):
            "URI: \(uri)"
        case let .text(text, _):
            "Text: \(text)"
        case let .mime(mimeType, payload):
            "MIME \(mimeType): \(payload.count)B"
        case let .aar(packageName):
            "AAR: \(packageName)"
        case let .unknown(tnf, _, payload):
            "unknown (tnf=\(tnf), \(payload.count)B)"
        }
    }
}
