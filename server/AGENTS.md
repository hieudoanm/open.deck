# server

`open-deck-server` — the Rust companion process that captures the primary
monitor and streams JPEG frames to OpenDeck clients over WebSocket, while
injecting their mouse/keyboard/text input back into the OS.

## Commands

```bash
cd server
cargo run --release -- --port 47821 --fps 15 --quality 70
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
```

Useful flags: `--bind`, `--port` (default `47821`), `--fps`, `--quality`,
`--max-width`, `--token` (or `OPENSDECK_TOKEN`). The startup banner prints the
pairing token, WebSocket URL, path, and monitor size — desktop companion apps
parse it, so keep the format stable.

HTTP endpoints: `GET /health`, `GET /status` (JSON client count + desktop/stream
info), `GET /ports` + `GET /apps` (host introspection — listening sockets via
`lsof`/`netstat`, processes via `sysinfo`; both spawn-blocking), and
`GET /ws?token=…` for the WebSocket upgrade.

## Structure

- `src/main.rs` — CLI args (`clap`), Axum router, per-client socket tasks,
  broadcast frame fan-out, client counter.
- `src/capture.rs` — monitor enumeration + frame capture (`xcap`) and JPEG
  encoding (`image`); emits `protocol::Frame` on a `tokio::broadcast` channel.
- `src/stats.rs` — host metrics sampler (`sysinfo`, ~2s cadence) broadcast as
  `ServerMessage::Stats`; each client socket forwards the latest snapshot so
  mobile System pages can show desktop stats.
- `src/hostinfo.rs` — `GET /ports` + `GET /apps` collectors: lsof on unix /
  netstat on Windows for listening sockets (pid + process name), sysinfo for
  the process list (cpu/mem). Blocking — handlers use `spawn_blocking`.
- `src/input.rs` — dedicated OS input thread (`enigo`) consuming
  `ClientMessage`s for mouse, scroll, key, and text injection.
- `src/protocol.rs` — serde wire types shared with every client. Normative spec:
  `docs/PROTOCOL.md` at repo root — update both together.

## Conventions

- Edition 2021; keep dependencies already in `Cargo.toml` unless the protocol
  genuinely requires otherwise.
- One broadcast frame is shared by all connected clients — do not encode
  per-client copies.
- The pairing token is the only auth; do not log it.
- Client → server traffic is JSON text frames; server → client is JSON text
  (`hello`/`pong`/`error`) plus binary JPEG frames.
- OS permissions differ per platform (Screen Recording/Accessibility on
  macOS, portal support on Wayland) — document changes rather than silently
  degrading capture or input.
