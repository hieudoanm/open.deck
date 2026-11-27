# AGENTS.md — desktop/macos

OpenDeck macOS companion: SwiftUI app (macOS 14+, Swift 5.10) that manages the
`open-deck-server` child process. Two parallel source trees exist — keep them
behaviorally aligned.

## Commands

```bash
cd desktop/macos
swift build                 # SwiftPM (Sources/OpenDeckMac)
swift run OpenDeckMac
# or
xcodegen generate           # only after editing project.yml
open OpenDeckMac.xcodeproj  # Xcode project (OpenDeckMac/ sources)
```

## Structure

- `Package.swift` — SwiftPM executable target `OpenDeckMac` → `Sources/`.
- `Sources/OpenDeckMac/` — canonical sources:
  - `OpenDeckApp.swift` — `@main`, `WindowGroup`, min 520×640.
  - `ServerManager.swift` — `ServerLocator.find()` candidate order:
    `$OPENSDECK_SERVER` → bundle exe dir → `PATH` → walk up 6 dirs for
    `server/target/{release,debug}/open-deck-server`. `@MainActor
ObservableObject` launches the binary with CLI flags, scrapes the
    `Pairing token`/`Monitor`/`WebSocket URL` stdout banner, polls
    `GET /status`, persists settings in `UserDefaults`.
  - `ContentView.swift` — status, pairing (token + QR), settings, log, controls.
  - `QRCodeView.swift` — CoreImage `CIQRCodeGenerator` → `NSImage`.
  - `Models.swift` — `ServerStatus` Decodable for `/status`.
- `project.yml` + `OpenDeckMac/` — xcodegen variant (bundle id
  `dev.opendeck.macos`, sources `OpenDeckMac/`). Both trees share the same
  sources; the QR payload is `opendeck://connect?host=…&port=…&token=…`
  (LAN IP via `getifaddrs`, en0 preferred).
- `OpenDeckMac.xcodeproj/` — generated; never hand-edit.

## Conventions

- `@MainActor` view model (`ObservableObject`/`@Published`); process I/O and
  HTTP polling must not block the main thread — use `readabilityHandler` +
  `Task { @MainActor }` and `Timer`.
- The server stdout banner format is a contract with `open-deck-server` —
  keep line parsing tolerant.
- `OPENSDECK_SERVER` env var is the supported override for locating the
  binary; keep it working in both trees.
- Do not commit `.build/` output.
