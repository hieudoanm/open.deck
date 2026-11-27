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
# tests (Swift Testing, needs a concrete simulator destination):
xcodebuild -project OpenDeck.xcodeproj -scheme OpenDeck \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -configuration Debug test CODE_SIGNING_ALLOWED=NO
```

## Structure

- `project.yml` — xcodegen spec: bundle id `com.opendeck.app`, sources =
  `OpenDeck/`, Info.plist properties, Swift 5.10, all orientations.
- `OpenDeck/OpenDeckApp.swift` — `@main`; hosts `DeckPagerView`; backgrounding
  disconnects the session (Android `onStop` parity).
- `OpenDeck/DeckPagerView.swift` — swipeable dashboard: `TabView(.page)` over
  `DeckPage` (deck/clock/system/ip/ports/apps/clipboard/nfc), custom tappable `PageDots`.
  Paging is disabled while the stream page is connected so its mouse drag
  gesture doesn't fight the pager pan.
- `OpenDeck/DeckModel.swift` — `@MainActor ObservableObject`: form fields
  (`host`, `port`, `token`), `status`, `connected`, `frame`, `hello`,
  `desktopStats` (server `stats` frames), `page`, NFC state
  (`nfcInfo`, `nfcBusy`, `writeText`/`writeURI`) and `nfcService`;
  `scanNfc`/`writeNfc`/`openNfc`/`closeNfc`; a scanned
  `opendeck://connect` URI record fills the form via `handleOpenURL`
  (Android `onTagScanned` parity); thin pass-throughs to `DeckClient`.
- `OpenDeck/DeckClient.swift` — `URLSessionWebSocketTask` client with a
  recursive `receive` loop; decodes binary frames as `UIImage`, parses
  `hello`/`pong`/`stats`/`error`, builds protocol JSON by string interpolation
  (escape `"` and `\` in `sendKey`).
- `OpenDeck/ConnectView.swift` — host/port/token form.
- `OpenDeck/StreamView.swift` — `GeometryReader` + `DragGesture`; `mapToDesktop`
  converts view → stream → absolute desktop pixels matching `.scaledToFit`
  letterboxing; bottom row sends ESC/TAB/↵/⌫/arrow keys.
- `OpenDeck/Clock/` — Clock suite ported from omni macOS (watchface, world
  clock, timer, stopwatch, pomodoro + Open-Meteo weather): `ClockModels`,
  `ClockFormatters`, `ClockViewModels` (`@MainActor ObservableObject`s),
  `ClockViews`, `WeatherService`, `Chime`.
- `OpenDeck/System/` — phone-local monitors (`SystemMonitor`: memory via
  `host_statistics64`, CPU via `host_processor_info`, battery via `UIDevice`,
  disk via `URLResourceValues`; `ByteFormatter`) plus `SystemView` which also
  renders `desktopStats` (server `{"type":"stats"}` frames, ~2s cadence) with
  a Phone/Desktop segmented toggle.
- `OpenDeck/IP/` — IP info page (local IPs, public IP lookup, network
  interfaces): `IPModels`, `IPViewModel`, `IPView`.
- `OpenDeck/Host/` — host-introspection pages fed by server HTTP endpoints:
  `HostModels.swift` (`PortEntry`/`AppEntry`/`ClipboardEntry` + `HostAPI`
  built from the connect form's host/port + pairing `token`),
  `PortsView.swift` (`GET /ports` 5s poll, search, swipe-to-kill →
  `POST /ports/kill` with SIGTERM/SIGKILL confirm), `AppsView.swift`
  (`GET /apps`, 2s poll, search) — ports of omni's Ports/Apps views.
- `OpenDeck/Clipboard/` — `UIPasteboard` history viewer with a
  Phone/Desktop toggle: desktop mode polls `GET /clipboard` and writes
  back via `POST /clipboard` (`ClipboardStore`, `ClipboardView`).
- `OpenDeck/NFC/` — NFC toolkit, parity with omni's `packages/mobile/ios`:
  `NdefCodec.swift` (pure NDEF parse/serialize — URI prefix table, text
  status byte, Smart Poster), `NdefPayload`/`NdefRecord`/`TagInfo` models,
  `NdefRecord` history-JSON coding (same DTO shape Android/omni persist),
  `NfcService.swift` (`NFCTagReaderSession` wrapper; reads/writes are
  user-initiated `async` one-shots, iOS has no ambient dispatch),
  `TagHistoryStore.swift` (scan history — JSON file in Application Support;
  omni uses SwiftData but that needs iOS 17 and we target 16),
  `SettingsStore.swift` (UserDefaults `auto_open_url`/`dark_mode` —
  `ObservableObject` instead of `@Observable`, same keys/defaults),
  `HistoryView.swift`/`SettingsView.swift` (sheets off `NfcView`'s toolbar),
  `NfcView.swift` (scan/write UI mirroring Android's `NfcScreen`).
- `OpenDeckTests/` — Swift Testing suites ported from omni's OmniTests:
  `NdefCodecTests`, `NdefRecordCodableTests`, `SettingsStoreTests`
  (`xcodebuild test`, see Commands).
- Deep links — `opendeck://connect?host=…&port=…&token=…` (the desktop QR
  payload) is registered via `CFBundleURLTypes` in `project.yml`/`Info.plist`
  and handled by `DeckModel.handleOpenURL`; keep the scheme in sync with the
  desktop companions and `mobile/android`'s intent filter.
- `OpenDeck/StreamView.swift` — `GeometryReader` + `DragGesture`; `mapToDesktop`
  converts view → stream → absolute desktop pixels matching `.scaledToFit`
  letterboxing; top bar has NFC + Disconnect; bottom row sends
  ESC/TAB/↵/⌫/arrow keys.
- `OpenDeck/StreamView.swift` — stream page inside the pager (see above).

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
