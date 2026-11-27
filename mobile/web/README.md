# OpenDeck Web

Browser client for `open-deck-server` — a zero-build single-file web app
(`index.html`) that mirrors the mobile apps' core remote-desktop flow:

- Connects to `ws://<host>:<port>/ws?token=<pairing token>`
- Renders binary JPEG frames on a canvas
- Mouse move/buttons/scroll → absolute desktop pixels (scaled via the
  `hello` frame's `desktop_*`/`stream_*` fields)
- Keyboard → named keys (`Return`, `Escape`, arrows, `F1`–`F12`, …),
  printable characters via the `text` message, and `Control+S`-style
  chords for `state:"press"`
- On-screen key bar (Esc/Tab/Enter/Bksp/Del/arrows/CAD)

## Usage

Serve the file over HTTP (browsers block `ws://` from `file://` in some
configurations, and HTTPS pages can't open `ws://` — plain HTTP only):

```sh
cd mobile/web
python3 -m http.server 8080
# open http://localhost:8080/
```

Or drop `index.html` on any static host / GitHub Pages alongside the
landing site. Enter the host, port (default `47821`), and the pairing
token printed by `open-deck-server`.

Protocol reference: `docs/PROTOCOL.md` at the repo root.
