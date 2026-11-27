# Architecture

OpenDeck is two processes talking over one WebSocket:

```text
┌────────────┐   JPEG frames    ┌──────────────┐   JSON input   ┌───────────┐
│  your PC   │ ───────────────▶ │  your phone  │ ─────────────▶ │  back to  │
│  monitor   │                  │  OpenDeck app│                │  the PC   │
└─────┬──────┘                  └──────────────┘                └─────┬─────┘
      │                                                             │
      │              open-deck-server (Rust)                        │
      │   capture (xcap) ─▶ JPEG encode ─▶ broadcast ─▶ WebSocket   │
      │                                                             │
      │              input thread (enigo) ◀── JSON messages ◀───────┘
      └─────────────────────────────────────────────────────────────┘
```

## Server side (`server/`)

A single Rust binary, `open-deck-server`, built on axum + tokio:

- **Capture** (`capture.rs`) — `xcap` grabs the primary monitor, the frame is
  downscaled to `--max-width` and JPEG-encoded at `--quality`, then pushed to a
  tokio broadcast channel at `--fps`.
- **Streaming** — each connected WebSocket client receives every frame as a
  binary message plus JSON text messages (`hello`, `error`).
- **Input injection** (`input.rs`) — client JSON messages (`mouse_move`,
  `mouse_button`, `scroll`, `key`, `text`) are forwarded over an mpsc channel to
  a dedicated thread that drives `enigo`, preserving ordering and keeping
  blocking OS calls off the async executor.

## Client side (`mobile/`)

- **Android** — Kotlin app (`com.opendeck.app`) with a `DeckClient` WebSocket
  client, a `DeckViewModel`, and a Compose `StreamView` that decodes JPEG frames
  and hit-tests touches into absolute desktop coordinates.
- **iOS** — SwiftUI app with `DeckClient` (URLSessionWebSocketTask),
  `DeckModel`, `StreamView` and `ConnectView` for pairing.

## Desktop companions (`desktop/`)

Native helpers that make running the server pleasant:

- **macOS** (`OpenDeckMac`) — SwiftUI app that manages `open-deck-server`, shows
  status and renders a QR code for pairing.
- **Linux** (`opendeck-linux`) — GTK4/libadwaita tray-style companion with the
  same QR pairing flow.
- **Windows** (`OpenDeckWinUI`) — WinUI 3 companion that launches the server,
  shows the pairing token and renders the same QR deep link.

## Security model

- The server generates a random pairing token at startup (or takes
  `--token`/`OPENSDECK_TOKEN`) and rejects WebSocket upgrades without it.
- Traffic is plain `ws://` — intended for trusted LANs. There is no auth beyond
  the token and no encryption; do not expose the port to the internet.
- Input injection runs with your user session's permissions — treat the pairing
  token like a password.
