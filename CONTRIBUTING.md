# Contributing to OpenDeck

Thanks for contributing to OpenDeck, a local-first companion that streams your
desktop to a phone and turns touches into mouse and keyboard input.

## Product boundary

OpenDeck is local-first. The phone talks to `open-deck-server` over a WebSocket
on the LAN; there is no account system, cloud relay, telemetry, or hosted API.
Do not add remote services or weaken the pairing-token model without an
explicit design discussion.

## Repository layout

- `server/` — Rust companion server (`open-deck-server`): screen capture,
  JPEG-over-WebSocket streaming, and input injection.
- `mobile/android/` — Kotlin + Jetpack Compose Android client.
- `mobile/ios/` — SwiftUI iOS client.
- `desktop/linux/` — GTK4/libadwaita companion that manages the server and
  shows QR pairing.
- `desktop/macos/` — SwiftUI companion for macOS.
- `desktop/windows/` — WinUI 3 companion for Windows.
- `packages/landing/` — Next.js static site for the project docs and downloads.
- `docs/PROTOCOL.md` — normative wire protocol.

## Setup

```bash
git clone https://github.com/hieudoanm/open.deck.git
cd open.deck
pnpm install
```

Component prerequisites:

- Rust stable for `server/` and `desktop/linux/`.
- JDK 17+ and the Android SDK for `mobile/android/`.
- Xcode 16+ for `mobile/ios/` and `desktop/macos/`.
- .NET 8 SDK on Windows for `desktop/windows/`.
- GTK4/libadwaita development packages for `desktop/linux/` on Linux.

## Checks

Run the checks for every component you touch:

```bash
# Rust server
cd server
cargo fmt --all -- --check
cargo clippy --all-targets -- -D warnings
cargo test
cargo build --release

# Landing site
pnpm --filter @opendeck/landing typecheck
pnpm --filter @opendeck/landing lint
pnpm --filter @opendeck/landing build

# Android
cd mobile/android
./gradlew lint testDebugUnitTest assembleDebug

# iOS
cd mobile/ios
xcodebuild -project OpenDeck.xcodeproj -scheme OpenDeck \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build

# macOS companion
cd desktop/macos
xcodebuild -project OpenDeckMac.xcodeproj -scheme OpenDeckMac \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build

# Linux companion (Linux only)
cd desktop/linux
cargo fmt --all -- --check
cargo clippy --all-targets -- -D warnings
cargo check

# Windows companion (Windows only)
cd desktop/windows
dotnet build OpenDeckWinUI/OpenDeckWinUI.csproj -c Release
```

## Conventions

- Keep the wire protocol stable: update `docs/PROTOCOL.md` and
  `server/src/protocol.rs` together, and keep clients compatible.
- Screen frames are JPEG binary WebSocket frames; control messages are JSON
  text frames. `mouse_move` coordinates are absolute desktop pixels.
- Treat pairing tokens like passwords. Never log, commit, screenshot, or embed
  real tokens in docs/tests.
- The server binds `0.0.0.0` by default so LAN phones can connect; document any
  change that affects exposure or authentication.
- Use the existing platform UI/tooling conventions for each component rather
  than introducing a shared UI framework.
- Keep commits in Conventional Commits format; CI enforces commitlint on the
  commit-msg hook when hooks are installed.

## License

By contributing, you agree that your contributions will be licensed under the
repository license in [`LICENSE`](LICENSE) (MIT OR Apache-2.0).
