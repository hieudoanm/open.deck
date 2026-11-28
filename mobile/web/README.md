# OpenDeck Web

Browser dashboard for `open-deck-server` — React + Vite + Tailwind CSS +
daisyUI. Zero runtime dependencies of its own; the production build is
copied into `server/web/` and embedded into the server binary, so a single
`open-deck-server` download serves this UI at `http://<host>:<port>/`.

## Develop

```sh
pnpm install
pnpm dev        # vite dev server — skips the connect form and auto-connects
pnpm build      # outputs dist/
```

Dev auto-connect creds come from `?host=&port=&token=` URL params or the
`VITE_HOST` / `VITE_PORT` / `VITE_TOKEN` env vars (defaults
`127.0.0.1:47821`, empty token). Example:

```sh
open-deck-server --token dev &
VITE_TOKEN=dev pnpm dev
```

Copy the build into the server (or use `make web` from the repo root):

```sh
rm -rf ../../server/web && cp -r dist ../../server/web
```

## Features

- Connect form (host/port/pairing token); `?host=&port=&token=` URL params
  prefill and auto-connect — the server's startup QR encodes this URL
- Three swipeable widget pages: system stats (WS `stats` feed), listening
  ports (`GET /ports`), top processes (`GET /apps`)
- Screen wake lock with a muted-video fallback for insecure (http://) contexts
- Installable PWA (manifest + icons in `public/`)
