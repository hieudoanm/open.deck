# Installation

## Prerequisites

- [Rust](https://rustup.rs/) stable (server and Linux companion app)
- Android Studio or JDK 17+ (Android app)
- Xcode 16+ and [xcodegen](https://github.com/yonaskolb/XcodeGen) (iOS app)
- Swift 5.10+ (macOS companion app)

## Build the server

```sh
git clone https://github.com/hieudoanm/open.deck.git
cd open.deck/server
cargo build --release
./target/release/open-deck-server --help
```

The binary lands at `server/target/release/open-deck-server`.

## Build the phone app

**Android**

```sh
cd mobile/android
./gradlew installDebug
```

**iOS**

```sh
cd mobile/ios
xcodegen generate
open OpenDeck.xcodeproj
```

Then build and run the `OpenDeck` scheme on a device or simulator.

## Build the desktop companion apps

**macOS**

```sh
cd desktop/macos
swift run OpenDeckMac
```

**Linux** (GTK4 + libadwaita dev packages required)

```sh
cd desktop/linux
cargo build --release
```

## Prebuilt binaries

Binaries for released platforms are attached to the
[GitHub releases](https://github.com/hieudoanm/open.deck/releases) page — see
[Downloads](../../../downloads/) for the current matrix.
