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

            Text(model.status)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
    }
}
