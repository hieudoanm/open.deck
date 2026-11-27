# open-deck-server

Companion server for [OpenDeck](../README.md): captures your primary monitor
and streams it to a phone over WebSocket, then injects the phone's touch,
keyboard, and mouse input back into the desktop.

## Run

```bash
cd server
cargo build --release
./target/release/open-deck-server
```

The server prints a pairing token on startup — enter it (with your PC's LAN IP
and port `47821`) in the Android or iOS app, or scan the QR code from a
desktop companion app.

```bash
./target/release/open-deck-server --port 47821 --fps 20 --quality 80
./target/release/open-deck-server --token MYTOKEN   # or OPENSDECK_TOKEN
./target/release/open-deck-server --bind 192.168.1.10
```

## Endpoints

| Route     | Purpose                                         |
| --------- | ----------------------------------------------- |
| `/health` | Liveness check (`ok`)                           |
| `/status` | JSON: connected clients, desktop size, FPS      |
| `/ws`     | WebSocket upgrade — requires `?token=<PAIRING>` |

## Protocol

Wire format (JSON control frames + binary JPEG frames) is specified in
[`docs/PROTOCOL.md`](../docs/PROTOCOL.md) and implemented in `src/protocol.rs`.

## Platform notes

- **macOS**: grant **Screen Recording** and **Accessibility** permissions to
  the process running the server.
- **Windows**: capture works without elevation; input injection uses standard
  user input.
- **Linux**: X11 works out of the box; Wayland capture needs portal support.

## License

MIT OR Apache-2.0
