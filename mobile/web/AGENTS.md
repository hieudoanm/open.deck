# OpenDeck Web

Browser dashboard for `open-deck-server` — React 19 + Vite + TypeScript +
Tailwind CSS v4 + daisyUI 5. The production build (`dist/`) is copied to
`server/web/` and embedded into the server binary via `include_dir`, so a
single `open-deck-server` download serves this UI at `http://<host>:<port>/`.

## Commands

```bash
pnpm install
pnpm dev          # vite dev server (port 5173)
pnpm build        # tsc -b && vite build -> dist/
pnpm preview      # serve the production build locally
pnpm format       # prettier --write (tailwind class sorting enabled)
pnpm format:check
pnpm lint         # eslint --fix
pnpm lint:check   # eslint
make web          # from repo root: install + build + copy dist -> server/web
```

`predev` kills anything on port 5173 (`kill-port`); `prebuild` cleans `dist/`
(`rimraf`).

## Structure

- `index.html` — Vite entry; PWA metas (manifest, apple-touch-icon,
  `black-translucent`, `theme-color`), zoom disabled via viewport meta
- `src/main.tsx` / `src/App.tsx` — mount + connect ↔ deck session state;
  `?host=&port=&token=` URL params prefill and auto-connect (the server's
  startup QR encodes this URL)
- `src/components/` — `ConnectView` (daisyUI card/inputs), `DeckView`
  (top bar, swipe pager, dots, nav buttons, `POST /open`), `SystemPage` +
  `Pages` (stat widgets + ports/apps lists), `BookmarksPage`, `Widget`
- `src/hooks/` — `useWakeLock` (native Screen Wake Lock → hidden muted
  `wake.mp4` fallback for insecure http:// contexts), `useNow` (clock)
- `src/data/bookmarks.ts` — generated bookmark list migrated from
  `omni/packages/web` `apps.csv` (Phosphor icons via `react-icons/pi`)
- `src/lib/format.ts` — `fmtBytes` / `fmtRate` / `fmtUptime`
- `src/types.ts` — WS/HTTP payload types mirroring `server/src/protocol.rs`
- `src/index.css` — Tailwind/daisyUI imports, custom `opendeck` theme,
  widget/pager/bookmark styles using `cqw`/`cqh` container units
- `public/` — `manifest.webmanifest`, `icons/`, `wake.mp4` (copied to dist root)

## Conventions

- After editing, run `make web` (or `pnpm build` + copy `dist/` to
  `server/web/`) — `server/web/` is committed build output; never edit it.
- Keep `pnpm-lock.yaml` committed; deps are pinned exact in `package.json`.
- The pager pages are a fixed array in `DeckView` — new pages get dots,
  arrows, and swipe support automatically.
- Bookmark tiles call `POST /open?token=…` on the server (token-gated);
  links open on the **host desktop's** default browser.
- ESLint uses `eslint-plugin-react-hooks` — avoid synchronous `setState`
  inside effect bodies (`react-hooks/set-state-in-effect`).
