# AGENTS.md — packages/landing

Next.js 16 (App Router) static-export site + Tailwind CSS v4 + DaisyUI 5,
deployed to GitHub Pages at `https://hieudoanm.github.io/open.deck/` (project
site — `basePath`/`assetPrefix` are `/open.deck` in production).

## Commands

```bash
pnpm install
pnpm run dev        # dev server (basePath applies)
pnpm run build      # static export → out/
pnpm run lint
pnpm run typecheck
pnpm run format     # prettier --write
```

## Structure

- `src/app/layout.tsx` — metadata, Inter via `next/font`, theme-init script,
  global `Navbar`/`Footer` (content passed as props).
- `src/app/page.tsx` — home page: hero (with CSS phone/stream-deck mockup),
  how-it-works, features, quickstart terminals, CTA.
- `src/app/downloads/page.tsx` — desktop + mobile download cards linking to
  GitHub releases, plus build-from-source commands.
- `src/app/docs/[[...slug]]/page.tsx` — docs rendered from `docs/*.md`.
- `src/app/api/search-index/route.ts` — statically-exported GET route handler
  powering `DocsSearch`.
- `src/components/molecules/` — shared components (`Navbar`, `Hero`, `Features`,
  `CTA`, `Footer`, `SectionHead`, `ThemeToggle`, `DocsSearch`). These files are
  **byte-identical across all `hieudoanm/*/packages/landing` repos** (only the
  theme names in `ThemeToggle` differ per repo) — do not fork them; pass content
  via props instead.
- `src/lib/docs.ts` — markdown → HTML pipeline (marked, heading ids, `.md` link
  rewriting, plain-text extraction). `REPO_BLOB` and `BASE_PATH` are
  repo-specific constants at the top.
- `src/lib/sections.ts` — docs sidebar grouping (`DOC_SECTIONS`).
- `docs/` — documentation source. `docs/README.md` is the index at `/docs/`;
  subdirectories map to sidebar sections.
- `public/` — `logo.svg`, `favicon.svg`, `icon.svg`, `og.svg`, `manifest.json`,
  `robots.txt`, `humans.txt`, `llms.txt`.

## Conventions

- Keep `output: "export"` in `next.config.ts` — the site must build to static
  HTML in `out/`; no server features beyond the static route handler.
- `basePath`/`assetPrefix` are `/open.deck` in production builds; `next/link`
  and metadata get it automatically, but raw `<img src>`, `fetch()` and
  hand-written `href`s must include it (see `layout.tsx`, `lib/docs.ts`).
- Theme is light/dark via `data-theme="opendeck"`/`"opendeck-dark"` on `<html>`;
  tokens are defined in `src/app/globals.css` (DaisyUI
  `@plugin 'daisyui/theme'`). The init script in `layout.tsx` must stay in sync
  with `ThemeToggle`'s storage key and theme names.
- Fonts: Inter via `next/font`; mono stack for terminal/code only.
- Styling: Tailwind utilities + DaisyUI components; no custom CSS beyond
  `globals.css` theme/prose blocks. Markdown HTML gets utility classes from
  `lib/docs.ts`, never custom selectors.
- Design follows the "AI unslop" rules: no filler badges, monospace only for
  code/commands, real CLI output in demos.
- Docs markdown links between pages use relative `.md` paths — `lib/docs.ts`
  rewrites them to `/docs/.../` URLs; links that escape the docs tree resolve to
  `REPO_BLOB` on GitHub.
- The pnpm lockfile lives at the workspace root (`pnpm-lock.yaml`); this package
  has no lockfile of its own.

<!-- BEGIN:nextjs-agent-rules -->

## This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may
all differ from your training data. Read the relevant guide in
`node_modules/next/dist/docs/` (resolved from this file's directory; in
monorepos the `next` package may not be visible from the repo root) before
writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at
`node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a
diff only re-creates the uncommitted change; committing it with your work keeps
the tree clean.

<!-- END:nextjs-agent-rules -->
