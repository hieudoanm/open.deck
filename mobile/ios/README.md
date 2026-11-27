# OpenDeck for iOS

SwiftUI app that turns an iPhone or iPad into a stream deck for
`open-deck-server`: live desktop over WebSocket and touch mapped to absolute
mouse coordinates.

## Requirements

- Xcode 16+ (Swift 5.10)
- [xcodegen](https://github.com/yonaskolb/XcodeGen) — `OpenDeck.xcodeproj` is
  generated from `project.yml`; do not hand-edit the project file

## Build & run

```bash
cd mobile/ios
xcodegen generate
open OpenDeck.xcodeproj
```

Then select the `OpenDeck` scheme and run on a device or simulator.
Command line:

```bash
xcodebuild -project OpenDeck.xcodeproj -scheme OpenDeck \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Bundle id: `com.opendeck.app`, deployment target iOS 16.0, all orientations.

## Usage

1. Run `open-deck-server` on your PC.
2. Open OpenDeck, enter the PC's LAN address, port (`47821`) and pairing token
   — or scan the pairing QR shown by a desktop companion app. The QR is an
   `opendeck://connect?host=…&port=…&token=…` deep link that fills the form —
   or use the NFC tools to read/write tags; a tag holding the pairing URI
   fills the form automatically.
3. Tap **Connect** — the desktop streams in; drag on the image to move/click
   the mouse, use the bottom bar for ESC/TAB/↵/⌫/arrows.

## NFC tools

**NFC tools** is on the connect screen and in the stream top bar. **Scan**
presents the system tag-reader UI and shows the tag's technologies and
decoded NDEF records (URI/text/MIME/AAR/unknown); **Write** puts a URI or
text record on a writable tag. Requires `NFCReaderUsageDescription` +
`OpenDeck.entitlements` (`com.apple.developer.nfc.readersession.formats`).
NFC is iPhone-only — iPads and the simulator show an unavailable state.

## Parity with Android

Feature parity is a goal — keep `mobile/android` and this app in sync.
Known platform differences:

- NFC scans are user-initiated sessions on iOS (no ambient dispatch);
  Android uses foreground dispatch.
- **Session focus mode is Android-only** — iOS has no AccessibilityService
  equivalent, so there is no "stay in app" enforcement.
- Auto-disconnect on exit is implemented on both (`scenePhase` background
  here, `onStop` on Android).

## Layout

- `OpenDeck/DeckClient.swift` — `URLSessionWebSocketTask` wrapper: JPEG binary
  frames → `UIImage`, JSON text frames → callbacks. Hand-built JSON for
  `mouse_move`, `mouse_button`, `key`.
- `OpenDeck/DeckModel.swift` — `@MainActor ObservableObject` holding the
  connect form, connection status, latest frame and `HelloInfo`; also parses
  `opendeck://connect` deep links (`handleOpenURL`) to pre-fill the form.
- `OpenDeck/ConnectView.swift` — pairing form plus the NFC-tools entry.
- `OpenDeck/NFC/` — NFC toolkit (parity with Android's `Nfc.kt`):
  `NdefCodec` (pure NDEF parse/serialize), `NdefPayload`/`NdefRecord`/
  `TagInfo` models, `NfcService` (`NFCTagReaderSession` read/write),
  `NfcView` (scan/write UI).
- `OpenDeck/StreamView.swift` — stream display with letterbox-aware
  touch→desktop coordinate mapping (`mapToDesktop`), `DragGesture` mouse
  control, top status bar, bottom control cluster.
- `OpenDeck/OpenDeckApp.swift` — `@main` entry; switches between
  `ConnectView`/`NfcView`/`StreamView`; disconnects the session when the
  app goes to `.background` (auto-disconnect parity with Android).

## Notes

- `NSAllowsArbitraryLoads` is enabled for plain `ws://` on the LAN — the
  protocol has no TLS.
- `mouse_move` coordinates are absolute desktop pixels, scaled from stream
  dims reported in the `hello` frame.
