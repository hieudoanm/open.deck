# OpenDeck for macOS

Native SwiftUI companion for `open-deck-server`: start/stop the server, tune
stream settings, watch live status, and show a QR code the phone app scans to
pair — no typing IPs and tokens.

## Requirements

- macOS 14+
- Swift 5.10 toolchain (Xcode or Command Line Tools)
- `open-deck-server` binary — built from `server/` in this repo, on `PATH`,
  next to the app, or pointed to with `OPENSDECK_SERVER`

## Build & run

SwiftPM (canonical sources in `Sources/OpenDeckMac/`):

```bash
cd desktop/macos
swift run OpenDeckMac
```

Or via the generated Xcode project (`OpenDeckMac/` sources, `project.yml`):

```bash
xcodegen generate   # if project.yml changed
open OpenDeckMac.xcodeproj
```

## What it does

- **Server management** (`ServerManager`) — `Process` wrapper that launches
  `open-deck-server` with `--port/--fps/--quality/--max-width/--token`,
  scrapes `Pairing token`/`Monitor` lines from stdout, and polls
  `GET /status` for client count.
- **Binary discovery** (`ServerLocator`) — checks `OPENSDECK_SERVER`, the app
  bundle directory, `PATH`, then walks up from the working directory looking
  for `server/target/{release,debug}/open-deck-server`.
- **Pairing QR** (`QRCodeView`) — renders the
  `opendeck://connect?host=<LAN-IP>&port=<port>&token=<token>` payload as a
  QR code via CoreImage so the phone app can scan it.
- **Settings** — port, fps, quality, max width and optional custom token,
  persisted in `UserDefaults`.

## Layout

- `Package.swift` + `Sources/OpenDeckMac/` — SwiftPM executable
  (`OpenDeckApp`, `ContentView`, `ServerManager`, `Models`, `QRCodeView`).
- `project.yml` + `OpenDeckMac/` + `OpenDeckMac.xcodeproj/` — xcodegen app
  project (parallel, slightly older variant of the same UI).
