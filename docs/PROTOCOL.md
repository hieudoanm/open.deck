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

### `stats` — host metrics (every ~2s)

While a session is connected, the server pushes a `stats` text frame roughly
every 2 seconds with host (desktop machine) metrics:

```json
{
  "type": "stats",
  "cpu_percent": 12.5,
  "mem_used": 8589934592,
  "mem_total": 17179869184,
  "swap_used": 0,
  "swap_total": 2147483648,
  "disk_used": 322122547200,
  "disk_total": 494384795648,
  "net_rx_rate": 15234,
  "net_tx_rate": 4210,
  "net_interfaces": [
    { "name": "en0", "rx_rate": 12000, "tx_rate": 3100 },
    { "name": "lo0", "rx_rate": 0, "tx_rate": 0 }
  ],
  "uptime_secs": 3600,
  "battery_percent": 87.5,
  "battery_state": "discharging",
  "memory_pressure": 12.0
}
```

Field notes:

- All sizes are **bytes**; `net_rx_rate`/`net_tx_rate` are **bytes per second**
  measured server-side (sum of `net_interfaces`).
- `net_interfaces` lists per-interface rates (name + rx/tx bytes/sec);
  omitted when empty.
- `disk_*` describes the root filesystem (or first mounted disk).
- `battery_percent`/`battery_state` are omitted when the host has no battery
  (desktop machines). `battery_state` is `"charging"`, `"discharging"`,
  `"full"`, `"ac"`, `"battery"`, or `"unknown"`.
- `memory_pressure` is a 0–100 pressure score (higher = more pressure);
  omitted on platforms without a probe (Windows).
- Clients use this to render "desktop" stat cards; phone-local stats remain
  client-side.

### Binary frames

Each binary WebSocket frame is one complete JPEG image of the primary
display, downscaled to fit `max_width`/`max_height` (default 1280). One encoded
frame is shared by all connected clients via broadcast.

## HTTP endpoints

In addition to the WebSocket, the server exposes small JSON endpoints used by
the desktop companions:

| Endpoint                        | Description                                                               |
| ------------------------------- | ------------------------------------------------------------------------- |
| `GET /health`                   | Liveness probe → `ok`                                                     |
| `GET /status`                   | `{clients, desktop_width, desktop_height, fps}`                           |
| `GET /devices`                  | `[{id, name, addr, connected_at}]` — connected clients                    |
| `POST /devices/{id}/disconnect` | Kick a device                                                             |
| `GET /actions`                  | `[{name, kind, detail}]` — available actions                              |
| `POST /actions/run?token=<t>`   | Body `{"name":"…"}` — run an action (requires pairing token)              |
| `GET /ports`                    | Listening TCP + bound UDP endpoints with pid/process                      |
| `POST /ports/kill?token=<t>`    | Body `{"pid":123,"force":false}` — SIGTERM/SIGKILL a pid                  |
| `GET /apps`                     | Running processes `[{pid,name,cpu_percent,mem_bytes}]`                    |
| `GET /clipboard?token=<t>`      | Desktop clipboard history `[{id,content,is_url,created_at,copied_count}]` |
| `POST /clipboard?token=<t>`     | Body `{"content":"…"}` — write to OS clipboard + record                   |
| `DELETE /clipboard?token=<t>`   | Clear desktop clipboard history                                           |

`/ports/kill` and all `/clipboard` routes require the pairing token —
kill is destructive and clipboard contents are private. `/ports/kill`
sends SIGTERM by default, SIGKILL when `"force":true`; the server's own
pid and pid 0/1 are refused.

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

{"type":"run_action","name":"media-play-pause"}

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
- `run_action` triggers a server-side action (media keys, custom commands —
  see `GET /actions`).
- The server replies `{"type":"pong"}` to `ping`.
