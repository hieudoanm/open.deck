# Mobile app — Android

The Android client (`mobile/android`, Kotlin + Jetpack Compose, package
`com.opendeck.app`, minSdk 26) shows the live desktop stream and turns touches
and keys into input events for `open-deck-server`.

## Requirements

- JDK 17+
- Android SDK (compileSdk 35), `ANDROID_HOME` set or `local.properties` with
  `sdk.dir`

## Build & install

```sh
cd mobile/android
./gradlew installDebug        # build + install on a connected device
./gradlew assembleDebug       # APK at app/build/outputs/apk/debug/
./gradlew lint testDebugUnitTest
```

## Pairing

Three ways to fill the connect form — all produce host/port/token:

1. **Manual** — type the PC's LAN address (e.g. `192.168.1.10`), port (default
   `47821`) and the pairing token printed by the server.
2. **QR scan** — scan the QR shown by a desktop companion app with the phone's
   camera. It encodes `opendeck://connect?host=…&port=…&token=…`; the manifest
   `VIEW` intent filter opens OpenDeck with the form pre-filled.
3. **NFC tap** — tap a tag holding the same URI (NDEF record). Works both from a
   cold start (`NDEF_DISCOVERED` filter) and inside the app (foreground
   dispatch). Any tag whose records contain an `opendeck://connect` URI fills
   the form automatically.

Then tap **Connect**.

## Controls

- **Touch the stream** — absolute-pointer mouse control: tap = click, drag =
  move/drag. Coordinates are scaled from stream pixels to desktop pixels via
  `mapToDesktop()` using the `desktop_*`/`stream_*` dims from the `hello` frame,
  matching `ContentScale.Fit` letterboxing.
- **Bottom bar** — ESC, TAB, ENTER, DEL and arrow keys.
- **Hardware keys** — `keyNameFor()` maps Android `KeyEvent`s (F1–F12, nav keys,
  etc.) to protocol key names.

## NFC tools

Open **NFC tools** from the connect screen (or the **NFC** button in the deck
top bar):

- **Read** — tap any NDEF tag to see its technologies and decoded records (URI /
  text / MIME / AAR / unknown). A pairing tag fills the connect form instead of
  opening the tools screen.
- **Write** — pick URI or Text, enter a value, tap **Write — then tap a tag**;
  the next scanned tag receives the record. Needs a writable NDEF/NdefFormatable
  tag.

## Session focus mode

Toggle **Session focus mode** on the connect screen to keep OpenDeck in the
foreground during a session: `OpenDeckAccessibilityService` watches window
changes and brings the app back if you switch away. Requires the Accessibility
permission — the app links to system settings. The setting persists in
SharedPreferences.

## Auto-disconnect on exit

`MainActivity.onStop` disconnects the WebSocket whenever a session is active —
home, recents or screen-off always ends the session.

## Troubleshooting

- _Can't connect_ — same subnet? LAN IP not `localhost`? Port open in the PC's
  firewall?
- _Connects then drops_ — wrong/rotated token; the server generates a new random
  token each launch unless a custom one is set.
- _Laggy picture_ — lower `--max-width` or `--fps` on the server.
- _NFC does nothing_ — device needs `android.hardware.nfc` (optional feature;
  check `NfcAdapter.getDefaultAdapter`), NFC enabled in system settings, and the
  tag held near the back of the phone.
- _Focus mode doesn't pull the app back_ — enable OpenDeck in system
  Accessibility settings; some OEM builds restrict background activity starts.
