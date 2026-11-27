# AGENTS.md — desktop/linux

OpenDeck Linux companion: Rust + GTK4 (`gtk4` 0.11) + libadwaita
(`libadwaita` 0.9) + `qrcode` 0.14. Single binary `opendeck-linux`, one source
file.

## Commands

```bash
cd desktop/linux
cargo build --release
cargo run --release
cargo fmt --all -- --check
cargo clippy --all-targets -- -D warnings
cargo check
```

Requires GTK4/libadwaita system dev packages on Linux.

## Structure

All code is in `src/main.rs`:

- `UiMsg` — enum of messages worker threads post to the GTK main loop.
- `Shared { child: Mutex<Option<Child>> }` — cross-thread handle to the
  server `Child` so Stop can kill it while the stdout reader polls `try_wait`.
- `locate_server()` — candidate order: `$OPENSDECK_SERVER` → exe dir → `PATH` →
  walk up 6 dirs for `server/target/{release,debug}/open-deck-server`.
- `fetch_status(port)` / `json_u64` — hand-rolled HTTP/1.1 GET against
  `127.0.0.1:<port>/status` (no HTTP client dep).
- `lan_ip()` — UDP-connect trick to pick the primary interface IPv4.
- `render_qr_svg()` — `qrcode` crate renders SVG; written to a temp file and
  shown via `gtk::Picture`.
- UI — adwaita `Window` + `HeaderBar` + `PreferencesGroup`s (Status, Pairing,
  Server settings) + log `TextView`, Start/Stop toggle.
- Server I/O — `Stdio::piped()` stdout/stderr reader threads parse banner
  lines (`Pairing token`, `Monitor`, `WebSocket URL`) into `UiMsg`s.

## Conventions

- **Never touch GTK widgets off the main loop** — workers communicate only via
  `UiMsg` sent on an `std::sync::mpsc` channel, drained by a 50ms
  `glib::timeout_add_local`.
- The server's stdout banner format (`Pairing token : …`, `Monitor : …`) is a
  contract with `open-deck-server`; keep parsing tolerant of extra lines.
- No new heavy dependencies — the crate intentionally uses raw `TcpStream`
  for `/status` instead of an HTTP client.
- The QR payload `opendeck://connect?host=…&port=…&token=…` is a contract with
  the desktop/mobile apps — keep it identical across platforms.
- Keep `Cargo.toml` `[package.metadata.bundle]` (`dev.opendeck.linux`) in sync
  if the app id changes.
