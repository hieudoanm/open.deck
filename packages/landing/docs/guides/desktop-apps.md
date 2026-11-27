# Desktop apps

The `desktop/` companions make running `open-deck-server` pleasant: they can
start/stop the server, show connection status, and display a QR code the phone
app scans to pair — no typing IPs and tokens.

## macOS — `OpenDeckMac`

SwiftUI app (`desktop/macos`, macOS 14+):

```sh
cd desktop/macos
swift run OpenDeckMac
```

## Linux — `opendeck-linux`

GTK4 + libadwaita companion (`desktop/linux`):

```sh
cd desktop/linux
cargo build --release
./target/release/opendeck-linux
```

Requires the GTK4/libadwaita development packages for your distribution.

## Windows — `OpenDeckWinUI`

WinUI 3 companion (`desktop/windows`, .NET 8, unpackaged). On Windows:

```powershell
cd desktop/windows
dotnet build OpenDeckWinUI.sln -c Release
```

It locates `open-deck-server.exe` next to the app, on `PATH`, or in the repo's
`server/target/release/` layout, then manages it with a Start/Stop toggle.

## QR pairing

The companions encode the pairing details as an
`opendeck://connect?host=<LAN-IP>&port=<port>&token=<token>` deep link. Both
phone apps register that scheme, so scanning the QR with the phone's camera
opens OpenDeck with the connect form pre-filled — treat the QR like the token
itself and don't screenshot it into shared spaces.
