# AGENTS.md — mobile/ios

OpenDeck iOS client: SwiftUI, iOS 16+, Swift 5.10. The Xcode project is
generated — `project.yml` (xcodegen) is the source of truth.

## Commands

```bash
cd mobile/ios
xcodegen generate              # regenerate OpenDeck.xcodeproj after editing project.yml
xcodebuild -project OpenDeck.xcodeproj -scheme OpenDeck \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

## Structure

- `project.yml` — xcodegen spec: bundle id `com.opendeck.app`, sources =
  `OpenDeck/`, Info.plist properties, Swift 5.10, all orientations.
- `OpenDeck/OpenDeckApp.swift` — `@main`; swaps `ConnectView`/`StreamView` on
  `DeckModel.connected`.
- `OpenDeck/DeckModel.swift` — `@MainActor ObservableObject`: form fields
  (`host`, `port`, `token`), `status`, `connected`, `frame`, `hello`, NFC
  state (`showNfc`, `nfcInfo`, `nfcBusy`, `writeAsUri`/`writeValue`) and
  `nfcService`; `scanNfc`/`writeNfc`/`openNfc`/`closeNfc`; a scanned
  `opendeck://connect` URI record fills the form via `handleOpenURL`
  (Android `onTagScanned` parity); thin pass-throughs to `DeckClient`.
- `OpenDeck/DeckClient.swift` — `URLSessionWebSocketTask` client with a
  recursive `receive` loop; decodes binary frames as `UIImage`, parses
  `hello`/`pong`/`error`, builds protocol JSON by string interpolation
  (escape `"` and `\` in `sendKey`).
- `OpenDeck/ConnectView.swift` — host/port/token form plus NFC-tools entry.
- `OpenDeck/NFC/` — NFC toolkit, parity with Android's `Nfc.kt`:
  `NdefCodec.swift` (pure NDEF parse/serialize — URI prefix table, text
  status byte, Smart Poster), `NdefPayload`/`NdefRecord`/`TagInfo` models,
  `NfcService.swift` (`NFCTagReaderSession` wrapper; reads/writes are
  user-initiated `async` one-shots, iOS has no ambient dispatch),
  `NfcView.swift` (scan/write UI mirroring Android's `NfcScreen`).
- Deep links — `opendeck://connect?host=…&port=…&token=…` (the desktop QR
  payload) is registered via `CFBundleURLTypes` in `project.yml`/`Info.plist`
  and handled by `DeckModel.handleOpenURL`; keep the scheme in sync with the
  desktop companions and `mobile/android`'s intent filter.
- `OpenDeck/StreamView.swift` — `GeometryReader` + `DragGesture`; `mapToDesktop`
  converts view → stream → absolute desktop pixels matching `.scaledToFit`
  letterboxing; top bar has NFC + Disconnect; bottom row sends
  ESC/TAB/↵/⌫/arrow keys.
- `OpenDeck/OpenDeckApp.swift` — routes `ConnectView`/`NfcView`/`StreamView`
  on `model.showNfc`/`model.connected`; `scenePhase == .background`
  disconnects the session (Android `onStop` parity).

## Conventions

- The wire protocol is the contract — `docs/PROTOCOL.md` and
  `server/src/protocol.rs` are normative. `mouse_move` uses absolute desktop
  pixels; scale via `hello`'s `desktop_*`/`stream_*` fields.
- Regenerate with `xcodegen generate` after changing `project.yml`; never
  hand-edit `OpenDeck.xcodeproj/`.
- Plain `ws://` only (LAN); `NSAllowsArbitraryLoads` is intentional.
- Keep the UI dark-first (`preferredColorScheme(.dark)`); no third-party
  dependencies.
- **Feature parity with `mobile/android` is a goal.** NFC read/write +
  pairing tags, auto-disconnect on exit exist on both. Session focus mode
  is Android-only (no iOS AccessibilityService equivalent); do not add
  Android-only APIs hoping for parity — document platform gaps in README.
- NFC needs `NFCReaderUsageDescription` (project.yml → Info.plist) and
  `OpenDeck/OpenDeck.entitlements` (`nfc.readersession.formats` = NDEF+TAG);
  `CODE_SIGN_ENTITLEMENTS` is set in project.yml. Real scans require a
  physical iPhone — the simulator reports NFC unavailable.
