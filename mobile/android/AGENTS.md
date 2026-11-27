# AGENTS.md — mobile/android

OpenDeck Android client: Kotlin + Jetpack Compose (Material 3), OkHttp
WebSocket, coroutines. Single-module Gradle project (`:app`), no version
catalog — dependency versions live in `app/build.gradle.kts`.

## Commands

```bash
cd mobile/android
./gradlew assembleDebug        # debug APK
./gradlew installDebug         # build + install on device
./gradlew lint testDebugUnitTest
./gradlew clean
```

Requires JDK 17+ and the Android SDK (`compileSdk = 35`, `minSdk = 26`).

## Structure

- `app/src/main/java/com/opendeck/app/DeckClient.kt` — WebSocket layer
  (OkHttp `WebSocketListener`). Binary frames → `Bitmap`; text frames parsed
  with `org.json`. Exposes `connect(url)`, `disconnect()`, `send(json)`,
  `sendMouseMove`, `sendMouseButton`, `sendKey`, and an `onStats` callback
  for server `{"type":"stats"}` host-metrics frames (~2s cadence).
- `DeckViewModel.kt` — `ViewModel` owning form state (`host`, `port`,
  `token`), `ConnState`, latest `ImageBitmap` frame, `HelloInfo`,
  `desktopStats`, `page` (`DeckPage`), `focusMode`, and NFC UI state
  (`nfcInfo`, `nfcBusy`, `writeAsUri`/`writeValue`, `pendingWrite`);
  publishes `SessionState.deckConnected` for the accessibility service.
- `MainActivity.kt` — `HorizontalPager` over `DeckPage` (deck/clock/system/
  ip/ports/apps/clipboard/nfc) with tappable dots — parity with iOS `DeckPagerView`;
  plus input mapping:
  `mapToDesktop()` converts view coords → stream coords → absolute desktop
  pixels (must match `ContentScale.Fit` letterboxing); `keyNameFor()` maps
  Android `KeyEvent`s to protocol key names; `handleDeepLink()` routes
  `opendeck://connect?host=…&port=…&token=…` intents (the desktop QR payload,
  registered in the manifest for both `VIEW` and `NDEF_DISCOVERED` so an NFC
  tag holding the URI also pairs) to `DeckViewModel.applyDeepLink`.
  `NfcDispatcher` is enabled in `onResume`/`onPause`; tag intents go to
  `DeckViewModel.onTagScanned`. `onStop` disconnects an active session.
- `Clock.kt`, `ClockViewModels.kt`, `ClockScreens.kt` — Clock suite ported
  from omni macOS (watchface, world clock, timer, stopwatch, pomodoro +
  Open-Meteo weather); coroutine-based VMs, parity with iOS `Clock/`.
- `SystemMonitor.kt`, `SystemScreen.kt` — phone-local stats (memory/CPU/
  battery/disk/network via `/proc`, `ActivityManager`, `BatteryManager`)
  plus desktop stats cards rendered from `desktopStats` behind a
  Phone/Desktop toggle (parity with iOS `System/`).
- `IPScreen.kt`, `IPService.kt` — IP info page (local interfaces + public IP
  lookup); parity with iOS `IP/`.
- `HostApi.kt`, `PortsScreen.kt`, `AppsScreen.kt` — host-introspection pages
  hitting the server's `GET /ports` (5s poll) and `GET /apps` (2s poll);
  parity with iOS `Host/` and omni's Ports/Apps views.
- `ClipboardScreen.kt` — clipboard history viewer (`ClipboardManager`);
  parity with iOS `Clipboard/`.
- `Nfc.kt` — NFC toolkit (ported from omni, no DI): `NfcTags.inspect/write`
  for NDEF read/write with URI/text/MIME record decoding, and
  `NfcDispatcher` wrapping `enableForegroundDispatch`.
- `Focus.kt` / `OpenDeckAccessibilityService.kt` — session focus mode:
  while connected and enabled, leaving OpenDeck brings it back via
  `TYPE_WINDOW_STATE_CHANGED` events. `FocusMode` persists the setting;
  the service reads SharedPreferences directly (no IPC).

## Conventions

- The wire protocol is the contract — `docs/PROTOCOL.md` at repo root and
  `server/src/protocol.rs` are normative. JSON is built by hand with
  `JSONObject.quote` for key strings; keep message shapes in sync with the
  server.
- `mouse_move` takes **absolute desktop pixels**, not normalized coords —
  always scale through the `hello` frame's `desktop_*`/`stream_*` fields.
- Compose-only UI, dark `MaterialTheme` color scheme, no XML layouts.
- `usesCleartextTraffic="true"` is required for `ws://`; do not add remote
  endpoints or weaken the pairing-token flow.
- Treat tokens as secrets — never log them.
