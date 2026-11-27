# OpenDeck

Turn an old phone into a "Steam Deck"-style remote desktop companion for your PC.
A companion server running on Windows, Linux, or macOS streams your desktop to
the phone, which sends touch/keyboard/mouse input back.

## Architecture

```
┌──────────────┐   WebSocket (JPEG frames + JSON input)   ┌──────────────────┐
│  Phone app   │ ───────────────────────────────────────▶ │ open-deck-server │
│ (Android/iOS)│ ◀─────────────────────────────────────── │  (Rust + Axum)   │
└──────────────┘                                          └────────┬─────────┘
                                                                    │ xcap + enigo
                                                          ┌─────────▼─────────┐
                                                          │   Your desktop    │
                                                          └───────────────────┘
```

Desktop companion apps (GTK4/libadwaita, SwiftUI, WinUI 3) are optional
front-ends that launch `open-deck-server`, display the pairing token, and
render a QR code for quick phone setup.

## Repository layout

| Path                | Component                                           | Stack                                     |
| ------------------- | --------------------------------------------------- | ----------------------------------------- |
| `server/`           | Companion server (screen capture + input injection) | Rust, Axum, WebSocket, xcap, enigo        |
| `mobile/android/`   | Android client                                      | Kotlin, Jetpack Compose, OkHttp WebSocket |
| `mobile/ios/`       | iOS client                                          | Swift, SwiftUI, URLSessionWebSocketTask   |
| `desktop/linux/`    | Linux companion (server manager + QR)               | Rust, GTK4, libadwaita                    |
| `desktop/macos/`    | macOS companion (server manager + QR)               | Swift, SwiftUI                            |
| `desktop/windows/`  | Windows companion (server manager + QR)             | C#, WinUI 3 (Fluent)                      |
| `packages/landing/` | Project site, docs, and downloads                   | Next.js static export                     |
| `docs/PROTOCOL.md`  | Wire protocol specification                         | —                                         |

## Quick start

### 1. Run the server on your PC

```bash
cd server
cargo build --release
./target/release/open-deck-server            # prints a pairing token
./target/release/open-deck-server --port 47821 --fps 20 --quality 80
./target/release/open-deck-server --token MYTOKEN   # or OPENSDECK_TOKEN env
```

Note: the server needs OS permissions to work fully:

- **macOS**: _System Settings → Privacy & Security_ — grant **Screen Recording**
  (capture) and **Accessibility** (input injection) to the terminal/app running
  the server.
- **Windows**: no special permissions for capture; input injection works for
  standard users.
- **Linux (X11)**: works out of the box. On **Wayland**, screen capture depends
  on portal support; input injection works via libei/ydotool-style backends.

### 2. Connect a phone

- **Android**: open `mobile/android` in Android Studio, run on your old phone
  (same Wi-Fi). Enter the PC's LAN IP, port (`47821`), and pairing token.
- **iOS**: `cd mobile/ios && xcodegen generate`, open `OpenDeck.xcodeproj`,
  run on device/simulator. Same connection fields.

### 3. Desktop companions (optional)

Each desktop app manages the server lifecycle for you:

- **Linux**: `cd desktop/linux && cargo build --release` (needs GTK4 +
  libadwaita dev packages). Expects `open-deck-server` on `PATH`.
- **macOS**: `cd desktop/macos && xcodegen generate && open OpenDeckMac.xcodeproj`.
  Put the `open-deck-server` binary in the app bundle Resources or on `PATH`.
- **Windows**: open `desktop/windows/OpenDeckWinUI.sln` in Visual Studio 2022
  (Windows 11 SDK required). Place `open-deck-server.exe` next to the exe or on `PATH`.

## Protocol

See [`docs/PROTOCOL.md`](docs/PROTOCOL.md). Summary: one WebSocket per client;
server → client binary JPEG frames + JSON hello/pong; client → server JSON
mouse/keyboard/text messages.

The project site and hosted docs live at
<https://hieudoanm.github.io/open.deck/>.

## License

MIT OR Apache-2.0
