# OpenDeck for Linux

GTK4 + libadwaita companion app for `open-deck-server`: it locates the server
binary, launches it, scrapes the pairing token from stdout, and shows live
status — including a QR code the phone app can scan to pair.

## Requirements

- Rust stable
- GTK4 and libadwaita development packages (e.g. `libgtk-4-dev`,
  `libadwaita-1-dev` on Debian/Ubuntu)

## Build & run

```bash
cd desktop/linux
cargo build --release
./target/release/opendeck-linux
```

## What it does

- **Server discovery** (`locate_server`) — checks `OPENSDECK_SERVER`, the app's
  own directory, `PATH`, then walks up to 6 parents looking for
  `server/target/{release,debug}/open-deck-server` (repo dev layout).
- **Process management** — spawns the server with piped stdout/stderr, a Start/
  Stop toggle, and kills the child on exit.
- **Pairing** — parses `Pairing token : …` and `Monitor : …` lines from server
  stdout, copies the token to the clipboard, and renders an
  `opendeck://connect?host=<LAN-IP>&port=<port>&token=<token>` QR code
  (`qrcode` crate → SVG temp file → `gtk::Picture`; LAN IP via the UDP-connect
  trick).
- **Status polling** — a `glib::timeout_add_local` every 2s does a raw-socket
  `GET /status` to show connected clients and monitor resolution.
- **Threading** — GTK only runs on the main loop; worker threads post `UiMsg`s
  over an `std::sync::mpsc` channel that a 50ms glib timeout drains.

## Layout

Single file: `src/main.rs` — `UiMsg` enum, `Shared` state, `locate_server`,
`fetch_status`, `lan_ip`, `render_qr_svg`, GTK/adwaita UI construction, and the
server stdout/stderr reader threads.
