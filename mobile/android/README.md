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
- `MainActivity.kt` — Compose UI: `ConnectScreen` (host/port/token form) and
  `DeckScreen` (stream view, letterbox-aware touch→desktop coordinate mapping,
  hardware-key mapping, control buttons); also routes deep-link intents to the
  view model.

## Notes

- Plain `ws://` — the manifest sets `usesCleartextTraffic="true"` because the
  protocol has no TLS; keep it on a trusted LAN.
- `mouse_move` coordinates are absolute desktop pixels; the client scales
  stream→desktop using `desktop_*`/`stream_*` dims from the `hello` frame.
