# Desktop companion — Windows

`OpenDeckWinUI` is the WinUI 3 companion for `open-deck-server` — a native
Fluent Design app that starts/stops the server, shows the pairing token and QR
code, and reports status. .NET 8, unpackaged (`WindowsPackageType=None`).

## Requirements

- Windows 10 1809+ (targets `net8.0-windows10.0.19041.0`, min 17763)
- .NET 8 SDK
- `open-deck-server.exe` — next to the app, on `PATH`, or in the repo's
  `server/target/release/` layout

## Build

```powershell
cd desktop/windows
dotnet build OpenDeckWinUI.sln -c Release
```

## Run

```powershell
.\OpenDeckWinUI\bin\x64\Release\net8.0-windows10.0.19041.0\win-x64\OpenDeckWinUI.exe
```

The app is unpackaged — no MSIX install needed. Solution platforms cover x86,
x64 and ARM64.

## Using the app

`MainWindow` is a single Fluent window:

- **Pairing token** — `TextBox` (editable; enter a custom token before starting
  if you want a stable one) with the server banner's token once running.
- **Port** — editable `NumberBox` (default `47821`); applied as `--port` when
  the server launches.
- **Start/Stop** — toggle button that spawns or kills `open-deck-server`.
- **Status text** — running state and errors; resets when the server process
  exits.
- **QR code** — rendered by QRCoder, encoding
  `opendeck://connect?host=<LAN-IP>&port=<port>&token=<token>` (`LanIp()` picks
  the primary interface address via a UDP-connect trick).

### First run

1. Build the server (`cd server && cargo build --release`) or place
   `open-deck-server.exe` where `FindServerBinary()` looks: the app's own
   directory → the repo's `server/target/release/` layout → `PATH`.
2. Optionally set a custom token and port.
3. Click **Start**. The app redirects the server's stdout, parses the
   `Pairing token` banner line, and shows token + QR.
4. On the phone: scan the QR with the camera (opens the `opendeck://` deep link)
   or tap an NFC tag holding the same URI — the connect form fills in; tap
   **Connect**.

### Day-to-day

- **Stop** terminates the server; if the server crashes or exits on its own, the
  `Exited` event resets the UI automatically.
- Firewall: allow `open-deck-server.exe` (and the port, default 47821) through
  Windows Defender Firewall on private networks, or the phone can't reach it.
- To change port/token, stop the server first — the fields feed the next
  launch's CLI flags.

## Troubleshooting

- _Server not found_ — copy `open-deck-server.exe` next to `OpenDeckWinUI.exe`,
  add it to `PATH`, or keep the repo layout.
- _Phone can't connect_ — check the firewall rule above; the QR embeds the PC's
  LAN IP, which a VPN can override — enter the host manually on the phone in
  that case.
- _QR pairs but connect fails_ — the token rotates each server launch unless you
  set a custom one; re-scan after restarting.
