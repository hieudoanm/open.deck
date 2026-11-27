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
  `sendMouseMove`, `sendMouseButton`, `sendKey`.
- `DeckViewModel.kt` — `ViewModel` owning form state (`host`, `port`,
  `token`), `ConnState`, latest `ImageBitmap` frame and `HelloInfo`.
- `MainActivity.kt` — all Compose UI plus input mapping:
  `mapToDesktop()` converts view coords → stream coords → absolute desktop
  pixels (must match `ContentScale.Fit` letterboxing); `keyNameFor()` maps
  Android `KeyEvent`s to protocol key names; `handleDeepLink()` routes
  `opendeck://connect?host=…&port=…&token=…` intents (the desktop QR payload,
  registered in the manifest for both `VIEW` and `NDEF_DISCOVERED` so an NFC
  tag holding the URI also pairs) to `DeckViewModel.applyDeepLink`.
  `NfcDispatcher` is enabled in `onResume`/`onPause`; tag intents go to
  `DeckViewModel.onTagScanned`. `onStop` disconnects an active session.
- `Nfc.kt` — NFC toolkit (ported from omni, no DI): `NfcTags.inspect/write`
  for NDEF read/write with URI/text/MIME record decoding, and
  `NfcDispatcher` wrapping `enableForegroundDispatch`.
- `DeckViewModel.kt` — also owns NFC UI state (`showNfc`, `nfcInfo`,
  `nfcBusy`, `writeAsUri`/`writeValue`, `pendingWrite`) and the
  `focusMode` toggle; publishes `SessionState.deckConnected` for the
  accessibility service.
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
