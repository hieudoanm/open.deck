# Desktop companion — macOS

`OpenDeckMac` is the SwiftUI companion for `open-deck-server`. It launches and
manages the server process, shows the pairing QR code, and polls live status.
Requires macOS 14+.

## Requirements

- macOS 14 or later
- Swift 5.10 toolchain (Xcode or Command Line Tools)
- The `open-deck-server` binary — built from `server/` in this repo, on `PATH`,
  next to the app, or pointed to with `OPENSDECK_SERVER`

## Build & run

Canonical sources are the SwiftPM package in `Sources/OpenDeckMac/`:

```sh
cd desktop/macos
swift build
swift run OpenDeckMac
```

There's also a parallel xcodegen Xcode project (`OpenDeckMac/` sources,
`project.yml` — regenerate with `xcodegen generate` after editing it, never
hand-edit the `.xcodeproj`):

```sh
xcodegen generate
open OpenDeckMac.xcodeproj
```

Both variants share the same behavior and QR payload.

## Using the app

The window has four areas:

- **Status** — server running state, LAN IP, port, connected phone clients and
  captured monitor resolution, refreshed by polling `GET /status`.
- **Pairing** — the pairing token plus a QR code rendered via CoreImage. The QR
  encodes `opendeck://connect?host=<LAN-IP>&port=<port>&token=<token>` (LAN IP
  via `getifaddrs`, `en0` preferred).
- **Settings** — port, fps, quality, max stream width, and an optional custom
  token. Persisted in `UserDefaults`.
- **Log** — the server's stdout/stderr banner and recent output.

### First run

1. Build the server once (`cd server && cargo build --release`) or set
   `OPENSDECK_SERVER=/path/to/open-deck-server`.
2. Launch the app. `ServerLocator` searches `$OPENSDECK_SERVER` → the app bundle
   directory → `PATH` → walks up 6 directories looking for
   `server/target/{release,debug}/open-deck-server`.
3. Press **Start** (or the equivalent control). `ServerManager` spawns the
   binary with `--port/--fps/--quality/--max-width/--token`, scrapes the
   `Pairing token`/`Monitor`/`WebSocket URL` banner lines, and starts polling
   `/status`.
4. Scan the QR with the phone app, or tap an NFC tag programmed with the same
   URI. The connect form fills in — tap **Connect** on the phone.

### Day-to-day

- **Stop** terminates the child process cleanly; quitting the app also kills the
  server it spawned.
- Change stream settings (fps/quality/max-width) and restart the server to apply
  them — they become CLI flags on the next launch.
- Set a custom token in Settings if you want a stable pairing token across
  restarts; otherwise each launch generates a random one.

## Troubleshooting

- _"Server binary not found"_ — check `OPENSDECK_SERVER`, or build
  `open-deck-server` into `server/target/release/` inside the repo.
- _Phone can't connect_ — both devices must share a subnet; the QR embeds the
  Mac's LAN IP (`en0` preferred), which can be wrong behind VPNs or with
  multiple interfaces — type the address manually then.
- _Status shows no clients after pairing_ — confirm the phone tapped
  **Connect**; `/status` only counts established WebSocket sessions.
