# Mobile app

The OpenDeck phone app is the client: it shows the live desktop stream and sends
your touches and keystrokes back to the server.

## Connecting

1. Start `open-deck-server` on your PC and note the printed pairing token.
2. Open the app and enter the server address — `192.168.1.10:47821` — or scan
   the QR code shown by a desktop companion app. The QR encodes an
   `opendeck://connect?host=…&port=…&token=…` deep link that fills the connect
   form automatically (Android intent filter / iOS `CFBundleURLTypes`).
3. Tap **Connect**.

## Controls

- **Touch the stream** — absolute-pointer mouse control: tap = click, drag =
  move/drag. Coordinates are scaled from stream pixels to desktop pixels using
  the `desktop_*`/`stream_*` dimensions from the `hello` frame.
- **On-screen keys** — the bottom bar sends `{"type":"key","state":"press"}` for
  ESC, TAB, ENTER, DEL and the arrow keys. Android also maps hardware keys
  (function keys, nav keys, etc.) through `keyNameFor`.

## Platform notes

- **Android** (`mobile/android`) — Kotlin + Jetpack Compose, package
  `com.opendeck.app`. Build with `./gradlew installDebug`.
- **iOS** (`mobile/ios`) — SwiftUI, deployment target iOS 16. Generate the Xcode
  project with `xcodegen generate`, then build the `OpenDeck` scheme.

## Troubleshooting

- _Can't connect_ — check the phone and PC are on the same subnet, the port is
  open in the firewall, and you used the LAN IP rather than `localhost`.
- _Connects then drops_ — the token is wrong or the server restarted with a new
  random token; re-enter it.
- _Laggy picture_ — reduce `--max-width` for less bandwidth, or lower `--fps`.
