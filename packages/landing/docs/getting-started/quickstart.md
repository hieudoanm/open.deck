# Quickstart

Get a phone showing your desktop and accepting input in three steps.

## 1. Start the server

```sh
cd server
cargo run --release -- --port 47821
```

On startup the server prints a pairing token and the address to give your phone:

```text
=== OpenDeck server is running ===
  Pairing token : 9f2c…e41a
  WebSocket URL : ws://<this-pc>:47821
  Path          : /ws?token=<token>
  Monitor       : 1920x1080 @ 15fps
===============================
```

Make sure your phone and PC are on the same network, and that your firewall
allows inbound TCP on the port (default `47821`).

## 2. Install the app on your phone

- **Android:** install the APK from
  [releases](https://github.com/hieudoanm/open.deck/releases), or build with
  `./gradlew installDebug`.
- **iOS:** build with Xcode (`xcodegen generate && open OpenDeck.xcodeproj`) or
  install from TestFlight when available.

## 3. Pair and connect

1. Open OpenDeck on the phone.
2. Enter your PC's LAN address and port (e.g. `192.168.1.10:47821`). The macOS
   and Linux companion apps show this as a QR code you can scan instead.
3. Paste the pairing token from the server output and tap **Connect**.

You should see your desktop live on the phone. Touch acts as the mouse — tap to
click, drag to drag, use the on-screen keyboard for text and shortcuts.

## Next steps

- Tune stream quality with `--fps`, `--quality` and `--max-width` — see
  [Server flags](../guides/server.md).
- Learn the wire format in [Architecture](../concepts/architecture.md) and the
  [Protocol](../concepts/protocol.md).
- The bottom bar sends common keys today; a configurable macro/deck grid is on
  the roadmap — see [Mobile app — Android](../guides/mobile-android.md) or
  [Mobile app — iOS](../guides/mobile-ios.md).
