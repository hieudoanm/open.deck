# Server

`open-deck-server` is the Rust binary in `server/`. It captures your primary
monitor, streams JPEG frames to connected phones, and injects the input it
receives back into your session.

## Flags

| Flag               | Default   | What it does                                     |
| ------------------ | --------- | ------------------------------------------------ |
| `--port <N>`       | `47821`   | TCP port to listen on                            |
| `--bind <ADDR>`    | `0.0.0.0` | Bind address (`127.0.0.1` for this machine only) |
| `--fps <N>`        | `15`      | Stream frames per second                         |
| `--quality <N>`    | `70`      | JPEG quality, 1–100                              |
| `--max-width <PX>` | `1280`    | Max stream width; height scales to keep aspect   |
| `--token <TOKEN>`  | random    | Pairing token (also `OPENSDECK_TOKEN` env var)   |

```sh
open-deck-server --port 47821 --fps 20 --quality 80 --token my-secret
```

## Notes

- **Multiple phones** can connect at once — every client gets every frame and
  every client's input is injected (think "shared remote").
- **Firewall** — the server binds all interfaces by default so phones on the LAN
  can reach it; allow the port in your OS firewall.
- **Performance** — capture only runs while at least one client is connected,
  and the capture loop sleeps between frames to hold `--fps`.
- **Token** — set `OPENSDECK_TOKEN` or `--token` for a stable token across
  restarts (handy for the QR-code companions, which embed it).
