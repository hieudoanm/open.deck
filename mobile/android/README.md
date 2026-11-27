# OpenDeck for Android

Kotlin + Jetpack Compose client that turns an Android phone into a stream deck
for `open-deck-server`: it shows the live desktop over WebSocket and sends
touch and key events back as JSON.

## Requirements

- JDK 17+
- Android SDK (compileSdk 35), `ANDROID_HOME` set or `local.properties` with
  `sdk.dir`

## Build & run

```bash
cd mobile/android
./gradlew installDebug        # builds and installs on a connected device
./gradlew assembleDebug       # APK at app/build/outputs/apk/debug/
./gradlew lint testDebugUnitTest
```

Application id: `com.opendeck.app`, minSdk 26, targetSdk 35.

## Usage

1. Run `open-deck-server` on your PC (`server/` in this repo).
2. Open OpenDeck, enter the PC's LAN address, port (default `47821`) and the
   pairing token printed by the server — or scan the pairing QR shown by a
   desktop companion app. The QR is an `opendeck://connect?host=…&port=…&token=…`
   deep link (manifest intent filters for `VIEW` and `NDEF_DISCOVERED`)
   that fills the form — scan the QR or tap an NFC tag holding the same URI.
3. Tap **Connect** — the desktop streams in; touch maps to absolute-pointer
   mouse control and the bottom bar sends ESC/TAB/ENTER/DEL/arrows.

## NFC tools

The connect screen has an **NFC tools** entry (also reachable from the deck
top bar). Tap any NDEF tag to see its technologies and decoded records
(URI/text/MIME). Use the write section to put a URI or text record on a
writable tag — tap-to-pair still works: a tag holding an
`opendeck://connect?…` URI fills the connect form automatically.

## Session focus & auto-disconnect

- **Session focus mode** (toggle on the connect screen) keeps OpenDeck in
  the foreground during a session via `OpenDeckAccessibilityService`. It
  needs the Accessibility permission — the app links to system settings.
- **Auto-disconnect on exit**: `MainActivity.onStop` disconnects the
  WebSocket when the app leaves the foreground, so sessions never linger
  after you switch away.

## Layout

- `app/src/main/java/com/opendeck/app/DeckClient.kt` — OkHttp WebSocket client:
  decodes JPEG binary frames to `Bitmap`, parses `hello`/`pong`/`error` text
  frames, builds protocol JSON (`mouse_move`, `mouse_button`, `key`).
- `app/src/main/AndroidManifest.xml` — permissions plus the `opendeck://`
  `VIEW`/`NDEF_DISCOVERED` intent filters for QR/NFC pairing links
  plus the `NFC` permission (`uses-feature` not required).
- `DeckViewModel.kt` — holds connection form state, latest frame
  (`ImageBitmap`) and `HelloInfo`; owns the `DeckClient`; `applyDeepLink`
  pre-fills the form from `opendeck://connect` links.
- `MainActivity.kt` — Compose UI: `ConnectScreen` (host/port/token form,
  NFC-tools entry, focus-mode toggle), `NfcScreen` (tag read/write) and
  `DeckScreen` (stream view, letterbox-aware touch→desktop coordinate
  mapping, hardware-key mapping, control buttons); routes NFC tag intents
  and deep links to the view model; `onStop` auto-disconnects.
- `Nfc.kt` — `NfcTags` (NDEF read/write + record decoding, ported from the
  omni NFC Toolkit) and `NfcDispatcher` (foreground dispatch).
- `Focus.kt` + `OpenDeckAccessibilityService.kt` — session focus mode:
  `SessionState.deckConnected` is set by the view model; the accessibility
  service (manifest-registered, `res/xml/accessibility_service_config.xml`)
  returns to OpenDeck when the user switches apps mid-session.
  `FocusMode` persists the toggle in SharedPreferences.

## Notes

- Plain `ws://` — the manifest sets `usesCleartextTraffic="true"` because the
  protocol has no TLS; keep it on a trusted LAN.
- `mouse_move` coordinates are absolute desktop pixels; the client scales
  stream→desktop using `desktop_*`/`stream_*` dims from the `hello` frame.
