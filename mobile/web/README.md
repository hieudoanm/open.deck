# OpenDeck Web

Browser dashboard for `open-deck-server` — React + Vite + Tailwind CSS +
daisyUI. Zero runtime dependencies of its own; the production build is
copied into `server/web/` and embedded into the server binary, so a single
`open-deck-server` download serves this UI at `http://<host>:<port>/`.

## Develop

```sh
pnpm install
pnpm dev        # vite dev server (proxy API calls to a running server if needed)
pnpm build      # outputs dist/
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
