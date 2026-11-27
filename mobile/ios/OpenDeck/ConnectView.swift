import SwiftUI

struct ConnectView: View {
    @ObservedObject var model: DeckModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("OpenDeck")
                .font(.largeTitle.bold())
            Text("Turn this phone into your Steam Deck")
                .foregroundStyle(.secondary)

            TextField("PC address (e.g. 192.168.1.10)", text: $model.host)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            HStack(spacing: 12) {
                TextField("Port", text: $model.port)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                SecureField("Pairing token", text: $model.token)
                    .textFieldStyle(.roundedBorder)
            }

            Button(action: model.connect) {
                Text(model.status == "Connecting…" ? "Connecting…" : "Connect")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.status == "Connecting…")

            // NFC tools entry (parity with Android's ConnectScreen)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NFC tools")
                    Text("Read / write tags & pairing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Open") { model.openNfc() }
            }

            Text(model.status)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Tip: scan the desktop QR or tap an NFC tag")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
    }
}
