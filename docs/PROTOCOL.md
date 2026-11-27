# OpenDeck Protocol

OpenDeck turns an old phone into a "Steam Deck"-style remote desktop
companion for your PC. The phone connects to `open-deck-server` running on
your Windows / Linux / macOS machine over a single WebSocket connection.

- Transport: WebSocket (`ws://<host>:<port>/ws?token=<PAIRING_TOKEN>`)
- Media: binary frames containing JPEG-encoded screen frames
- Control: JSON text frames in both directions

The normative Rust types live in `server/src/protocol.rs`; keep this document
and that file in sync.

## Connection

The server prints a pairing token on startup (or via `--token` /
`OPENSDECK_TOKEN`). The client must pass it as the `token` query parameter or
the upgrade is rejected with `401`.

## Server → Client

### Text frames (JSON)

The first text frame after the upgrade is `hello`, sent before the first
binary frame:

```json
{
  "type": "hello",
  "version": 1,
  "name": "open-deck-server",
  "desktop_width": 1920,
  "desktop_height": 1080,
  "stream_width": 1280,
  "stream_height": 720,
  "fps": 15,
  "max_fps": 15
}
```

Field notes:

- `desktop_*` is the captured monitor's native resolution; `stream_*` is the
  resolution of the JPEG frames actually sent (downscaled to `max_width`).
- `fps` is the configured capture rate; `max_fps` is the current ceiling.
- `{"type":"pong"}` answers a client `ping`; `{"type":"error","message":"…"}`
  is reserved for server-side failures.

### Binary frames

Each binary WebSocket frame is one complete JPEG image of the primary
display, downscaled to fit `max_width`/`max_height` (default 1280). One encoded
frame is shared by all connected clients via broadcast.

## Client → Server

All client messages are JSON text frames. Unknown or malformed messages are
dropped with a server-side warning.

```json
{"type":"hello","name":"Pixel 4","version":1}

{"type":"mouse_move","x":640,"y":360}
{"type":"mouse_button","button":"left","state":"down"}
{"type":"mouse_button","button":"left","state":"up"}
{"type":"scroll","dx":0,"dy":-3}

{"type":"key","key":"a","state":"down"}
{"type":"key","key":"a","state":"up"}
{"type":"key","key":"Return","state":"press"}

{"type":"text","text":"hello world"}

{"type":"ping"}
```

### Field notes

- Client `hello` is optional metadata (`name`, `version`); the server does not
  require it before accepting input.
- `x`/`y` for `mouse_move` are **absolute desktop pixels**, not normalized
  coordinates. Clients should scale touch coordinates from stream space into
  desktop space using `desktop_*` / `stream_*` from the server `hello` frame.
- `button` is one of `"left"`, `"right"`, `"middle"`, `"back"`, `"forward"`.
- `state` is `"down"`, `"up"`, or `"press"` (down+up).
- `key` accepts either a single character (`"a"`, `"A"`, `"1"`, `" "`), a key
  name (`"Return"`, `"Escape"`, `"Backspace"`, `"Tab"`, `"ArrowUp"`,
  `"ArrowDown"`, `"ArrowLeft"`, `"ArrowRight"`, `"F1"`–`"F12"`, `"Control"`,
  `"Alt"`, `"Shift"`, `"Super"`, …), or a `"Control+S"`-style chord for
  `key`/`state:"press"`.
- `scroll` `dx`/`dy` are wheel ticks (positive `dy` scrolls down, positive
  `dx` scrolls right).
- `text` types a literal string through the OS text-input path.
- The server replies `{"type":"pong"}` to `ping`.
