# Agent notes

## Build / verify commands

- Server: `cd server && cargo build` (verify: `cargo fmt --all -- --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`)
- Landing site: `pnpm install && pnpm lint && pnpm typecheck && pnpm --filter @opendeck/landing build`
- iOS app: `cd mobile/ios && xcodegen generate && xcodebuild -project OpenDeck.xcodeproj -scheme OpenDeck -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO`
- macOS app: `cd desktop/macos && xcodegen generate && xcodebuild -project OpenDeckMac.xcodeproj -scheme OpenDeckMac -configuration Debug build CODE_SIGNING_ALLOWED=NO`
- Linux GTK app: `cd desktop/linux && cargo build` — requires GTK4/libadwaita system deps; cannot build on macOS.
- Android: `cd mobile/android && ./gradlew assembleDebug` — requires Android SDK (not installed on this machine as of 2026-11).
- Windows: `dotnet build desktop/windows/OpenDeckWinUI/OpenDeckWinUI.csproj -c Release -p:Platform=x64` on Windows.

## Conventions

- Wire protocol is specified in `docs/PROTOCOL.md`; `server/src/protocol.rs`
  mirrors it — update both together.
- Mobile/desktop clients talk to `ws://<host>:<port>/ws?token=<token>`.
- Server prints a random pairing token unless `--token`/`OPENSDECK_TOKEN` is set.
- Screen frames are JPEG binary WS frames; control messages are JSON text frames.
- Keep OpenDeck local-first: no cloud relay, telemetry, accounts, or remote API.
  Treat pairing tokens like passwords and never commit real tokens.
- Git hooks (when installed): `.husky/pre-commit` runs lint-staged and
  `.husky/commit-msg` runs commitlint; see `CONTRIBUTING.md` for checks.
