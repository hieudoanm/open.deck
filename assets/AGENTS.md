# AGENTS.md — assets

## Sources of truth

- `branding/svg/*.svg` are the canonical logo/OG sources. `branding/png/`
  is generated output — never edit PNGs directly.

## After editing an SVG

1. Run `assets/svg-to-png.sh` (requires `rsvg-convert`) to regenerate the
   sibling `png/` outputs.
2. If the SVG feeds the landing page (`branding/*`), run
   `assets/sync-assets.sh` to update `packages/landing/public/`.

## Content rules

- `logo.svg` is 512x512; `og.svg` is 1200x630 (GitHub OG standard).
- Brand colors: primary blue `#2563eb`/`#3b82f6`/`#1d4ed8` (matches landing
  `--color-primary`), accent amber `#fbbf24` for the "active" deck cell,
  OG background `#0f172a`, OG accent text `#93c5fd`.
- The logo mark is a 3x3 rounded-square "deck" grid on a blue gradient
  badge — keep cell opacity variance and the amber center cell.
- Keep the font stack quote-free: `Inter, system-ui, sans-serif` — some SVG
  renderers fail on quoted family names.
- `og.svg` must stay self-contained (inline `<defs>` gradients, no external
  refs) so `rsvg-convert` and social scrapers can render it.
