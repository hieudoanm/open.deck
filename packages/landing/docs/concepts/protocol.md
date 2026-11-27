# Protocol

OpenDeck uses a single WebSocket connection per phone:

```text
ws://<host>:<port>/ws?token=<PAIRING_TOKEN>
```

- **Media:** binary frames, each one complete JPEG image of the primary display
  downscaled to `max_width`/`max_height`.
- **Control:** JSON text frames in both directions.

The full normative description lives in the repository:
[`docs/PROTOCOL.md`](https://github.com/hieudoanm/open.deck/blob/master/docs/PROTOCOL.md).

## Server → client

The first text frame after the upgrade is `hello`:

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

`desktop_*` is the monitor's native resolution; `stream_*` is the resolution of
the JPEG frames actually sent. `{"type":"error","message":"…"}` is reserved for
server-side failures.

## Client → server

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

The server answers `{"type":"pong"}` to `ping`.

## Field notes

- `x`/`y` for `mouse_move` are **absolute desktop pixels**. Scale touch
  coordinates from stream space into desktop space using `desktop_*` /
  `stream_*` from the server `hello` frame.
- `button` is `"left"`, `"right"`, `"middle"`, `"back"` or `"forward"`; `state`
  is `"down"`, `"up"` or `"press"`.
- `key` accepts a single character, a key name (`"Return"`, `"ArrowUp"`,
  `"F1"`–`"F12"`, `"Control"`, `"Alt"`, `"Shift"`, …) or a `"Control+S"`-style
  chord with `state:"press"`.
- `scroll` `dx`/`dy` are wheel ticks; positive `dy` scrolls down, positive `dx`
  scrolls right.
- `text` types a literal string through the OS text-input path.

Because the protocol is plain JSON over WebSocket, third-party clients — a
touchscreen kiosk, a Stream Deck hardware button bridge, a status dashboard —
are trivial to write.
