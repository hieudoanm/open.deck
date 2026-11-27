# assets

Branding and generated images for the `open.deck` repo.
Everything here is source material — the PNGs are generated, never
hand-edited.

## Layout

```
assets/
├── branding/
│   ├── svg/           # source SVGs: logo.svg (512x512), og.svg (1200x630)
│   └── png/           # rendered PNGs (logo.png 512x512, og.png 1200x630)
├── svg-to-png.sh      # render every */svg/*.svg -> sibling */png/*.png
└── sync-assets.sh     # copy branding into packages/landing/public
```

## The mark

The logo is a rounded-square badge (`#3b82f6 → #1d4ed8` diagonal gradient,
matching the landing's blue `--color-primary`) containing a 3×3 "deck" grid of
rounded buttons. Cells are white at varying opacity; the center cell is the
"active" button in amber (`#fbbf24`). Keep the grid asymmetric — the opacity
pattern is deliberate.

## Regenerating

```sh
assets/svg-to-png.sh    # needs rsvg-convert (brew install librsvg)
assets/sync-assets.sh   # syncs logo.svg/og.svg/og.png/favicon.ico into landing/public
```

`svg-to-png.sh` discovers SVGs recursively (`*/svg/*.svg`) and writes the
matching `*/png/` path at the SVG's intrinsic size.

`sync-assets.sh` copies `branding/svg/logo.svg` to
`public/{logo,icon,favicon}.svg`, copies `og.svg` to `public/og.svg`, renders
`public/og.png` at 1200x630, and rebuilds `favicon.ico` via ImageMagick.

## Consumers

- `README.md` / `RELEASE.md` — `assets/branding/png/og.png` (social preview),
  `assets/branding/png/logo.png`
- `packages/landing/` — `public/` assets synced by `sync-assets.sh`;
  `layout.tsx` references `/logo.svg`, `/icon.svg`, `/og.svg`
- Mobile/desktop app icons are **not** synced from here — each platform has
  its own icon pipeline (Android adaptive icon XML, iOS asset catalog, etc.)
