# Mobile app — iOS

The iOS client (`mobile/ios`, SwiftUI, deployment target iOS 16) shows the live
desktop stream and turns touches and keys into input events for
`open-deck-server`.

## Requirements

- macOS with Xcode + [xcodegen](https://github.com/yonaskolb/XcodeGen)
- An iPhone for NFC features (iPad and the simulator build fine but NFC reports
  unavailable)
- A physical device or simulator for the stream client itself

## Build

The Xcode project is generated — `project.yml` is the source of truth:

```sh
cd mobile/ios
xcodegen generate
xcodebuild -project OpenDeck.xcodeproj -scheme OpenDeck \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Or open `OpenDeck.xcodeproj` in Xcode and run on a device. Signing is required
for device builds (NFC needs the entitlements in
`OpenDeck/OpenDeck.entitlements`, wired via `CODE_SIGN_ENTITLEMENTS` in
`project.yml`).

## Pairing

1. Start `open-deck-server` on your PC and note the printed pairing token.
2. Open OpenDeck and enter the PC's LAN address, port (`47821`) and token — or
   scan the QR shown by a desktop companion app. The QR encodes an
   `opendeck://connect?host=…&port=…&token=…` deep link registered via
   `CFBundleURLTypes`; it fills the connect form automatically.
3. NFC: see below — a tag holding the same URI also fills the form.
4. Tap **Connect**.

## Controls

- **Drag on the stream** — absolute-pointer mouse control: touch = click, drag =
  move/drag. `mapToDesktop()` converts view → stream → desktop pixels, matching
  `.scaledToFit` letterboxing and the `desktop_*`/ `stream_*` dims from the
  `hello` frame.
- **Bottom bar** — ESC, TAB, ↵, ⌫ and arrow keys.

## NFC tools

Open **NFC tools** from the connect screen (or the **NFC** button in the stream
top bar). iOS scans are user-initiated `NFCTagReaderSession`s (no ambient
dispatch like Android):

- **Scan** — presents the system tag-reader UI; shows the tag's technologies,
  UID and decoded NDEF records (URI / text / MIME / AAR / unknown). A tag
  containing an `opendeck://connect` URI fills the connect form instead.
- **Write** — pick URI or Text, enter a value, tap **Write**, then hold the
  iPhone near a writable NDEF tag.

Requires `NFCReaderUsageDescription` (in `project.yml` → Info.plist) and the
`com.apple.developer.nfc.readersession.formats` entitlement (NDEF + TAG). On
iPad/simulator the screen shows "NFC is not available".

## Session focus mode

Not available on iOS — there is no AccessibilityService equivalent, so the app
can't enforce staying in the foreground. (Android-only feature; see
`mobile-android.md`.)

## Auto-disconnect on exit

`OpenDeckApp` watches `scenePhase`: when the app goes to `.background` with an
active session it disconnects — parity with Android's `onStop`.

## Troubleshooting

- _Can't connect_ — same subnet? LAN IP not `localhost`? Port open in the PC's
  firewall / macOS firewall?
- _Connects then drops_ — wrong/rotated token; the server generates a new random
  token each launch unless a custom one is set.
- _Laggy picture_ — lower `--max-width` or `--fps` on the server.
- _NFC scan does nothing_ — physical iPhone required (iPhone 7+); check Settings
  → General → About isn't needed, just ensure the device supports NFC and isn't
  in Airplane Mode with radios off.
- _Entitlement errors on device build_ — regenerate with `xcodegen generate` so
  `CODE_SIGN_ENTITLEMENTS` is picked up, and use a signing team that supports
  NFC capabilities.
