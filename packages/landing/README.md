# Landing

Next.js 16 (App Router) static-export site + Tailwind CSS v4 + DaisyUI — landing
page, docs and downloads for OpenDeck, deployed to GitHub Pages at
`https://hieudoanm.github.io/open.deck/` (project site —
`basePath: "/open.deck"` in production).

## Commands

```bash
pnpm install
pnpm run dev      # dev server (basePath applies)
pnpm run build    # static export → out/
pnpm run lint
pnpm run typecheck
```

## Structure

- `src/app/layout.tsx` — metadata, fonts, and the global `Navbar`/`Footer`.
- `src/app/page.tsx` — home page content passed to the shared components.
- `src/app/docs/[[...slug]]/page.tsx` — docs rendered from `docs/*.md`.
- `src/app/downloads/page.tsx` — desktop and mobile download links.
- `src/components/molecules/` — shared components (`Navbar`, `Hero`, `Features`,
  `CTA`, `Footer`, `SectionHead`, `ThemeToggle`, `DocsSearch`). These files are
  **byte-identical across all `hieudoanm/*/packages/landing` repos** (except
  per-repo theme names in `ThemeToggle`) — do not fork them; pass content via
  props instead.
- `src/lib/docs.ts` — markdown → HTML pipeline (marked + heading ids + link
  rewriting + search text). `REPO_BLOB`/`BASE_PATH` are repo-specific.
- `docs/` — documentation source (Markdown). `docs/README.md` is the docs index
  at `/docs/`.
- `public/` — `favicon.svg`, `icon.svg`, `logo.svg`, `og.svg`, `manifest.json`,
  `robots.txt`, `humans.txt`, `llms.txt`, served under `/open.deck/` in
  production.

## Conventions

- Keep `output: "export"` in `next.config.ts` — the site must build to static
  HTML in `out/`; the only server feature is the statically-exported
  `api/search-index` route handler used by docs search.
- `basePath`/`assetPrefix` are `/open.deck` in production builds; `next/link`
  and metadata get it automatically, raw `<img src>` and `fetch` paths must
  include it (see `layout.tsx` and `lib/docs.ts`).
- Theme is light/dark via `data-theme="opendeck"` / `"opendeck-dark"` on
  `<html>`; accent colours are defined in `src/app/globals.css`.
- Fonts: Inter via `next/font`; mono stack for terminal/code only.
- Design follows the "AI unslop" rules: no filler badges, monospace only for
  code/commands, real CLI output in demos.
