import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var manager: ServerManager

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statusSection
                    pairingSection
                    settingsSection
                    logSection
                }
                .padding(20)
            }
            Divider()
            controlsBar
        }
        .frame(minWidth: 520, minHeight: 640)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "gamecontroller.fill")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("OpenDeck")
                    .font(.title2.bold())
                Text("Turn this Mac into a Steam Deck companion for your phone")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            stateBadge
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var stateBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(manager.isRunning ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 8, height: 8)
            Text(manager.isRunning ? "Running" : "Stopped")
                .font(.callout.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.quaternary, in: Capsule())
    }

    // MARK: - Status

    private var statusSection: some View {
        GroupBox("Status") {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow {
                    Text("Server binary").foregroundStyle(.secondary)
                    Text(manager.serverPath ?? "not found")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    if manager.serverPath == nil {
                        Button("Rescan") { manager.rediscoverServer() }
                    }
                }
                GridRow {
                    Text("Connected devices").foregroundStyle(.secondary)
                    Text("\(manager.clients)")
                }
                if let monitor = manager.monitorInfo {
                    GridRow {
                        Text("Monitor").foregroundStyle(.secondary)
                        Text(monitor)
                    }
                }
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Pairing

    @ViewBuilder
    private var pairingSection: some View {
        GroupBox("Pairing") {
            if let token = manager.token, let payload = manager.connectURLString {
                HStack(alignment: .top, spacing: 20) {
                    QRCodeView(payload: payload)
                        .padding(8)
                        .background(.white, in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("Token") {
                            Text(token)
                                .font(.system(.title3, design: .monospaced).bold())
                                .textSelection(.enabled)
                        }
                        LabeledContent("Address") {
                            Text(manager.wsURLString ?? "")
                                .font(.callout.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        Text("On your phone, enter this Mac's LAN IP (\(manager.lanIP ?? "—")), port \(manager.port), and the token — or scan the QR code.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Start the server to generate a pairing token.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        GroupBox("Server settings") {
            Form {
                LabeledContent("Port") {
                    TextField("", value: $manager.port, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .disabled(manager.isRunning)
                }
                LabeledContent("Frame rate") {
                    Stepper("\(manager.fps) fps", value: $manager.fps, in: 1...60)
                        .disabled(manager.isRunning)
                }
                LabeledContent("JPEG quality") {
                    Slider(value: Binding(
                        get: { Double(manager.quality) },
                        set: { manager.quality = Int($0) }
                    ), in: 1...100, step: 1) {
                        Text("\(manager.quality)%")
                    }
                    .disabled(manager.isRunning)
                }
                LabeledContent("Max width") {
                    TextField("", value: $manager.maxWidth, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .disabled(manager.isRunning)
                }
                LabeledContent("Token (optional)") {
                    TextField("auto-generate", text: $manager.customToken)
                        .frame(width: 160)
                        .disabled(manager.isRunning)
                }
            }
            .formStyle(.grouped)
        }
    }

    // MARK: - Log

    private var logSection: some View {
        GroupBox("Log") {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(manager.logLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(8)
            }
            .frame(height: 120)
        }
    }

    // MARK: - Controls

    private var controlsBar: some View {
        HStack {
            if case .failed(let message) = manager.state {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text("Changes to settings apply after restarting the server.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button(manager.isRunning ? "Stop" : "Start") {
                manager.isRunning ? manager.stop() : manager.start()
            }
            .buttonStyle(.borderedProminent)
            .tint(manager.isRunning ? .red : .accentColor)
            .disabled(manager.serverPath == nil && !manager.isRunning)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
