# OpenDeck documentation

**OpenDeck** turns an old phone into a "Stream Deck"-style companion for your
PC. A small Rust server on your desktop captures the screen and injects input;
the phone app shows the live desktop and turns touches into mouse and keyboard
events — all over a single WebSocket on your local network.

## Sections

- **Getting started** — install the server and apps, pair your phone.
- **Concepts** — how capture, streaming and input injection fit together.
- **Guides** — server flags plus per-platform guides for the desktop companions
  (macOS, Linux, Windows) and phone apps (Android, iOS).

## Components

| Component          | What it is                                                                |
| ------------------ | ------------------------------------------------------------------------- |
| `open-deck-server` | Rust server (`server/`) — screen capture + WS stream + input injection    |
| Android app        | Kotlin app (`mobile/android`) — the phone client                          |
| iOS app            | SwiftUI app (`mobile/ios`) — the phone client                             |
| macOS app          | SwiftUI companion (`desktop/macos`) — runs the server, shows a pairing QR |
| Linux app          | GTK4/libadwaita companion (`desktop/linux`)                               |
| Windows app        | WinUI companion (`desktop/windows`)                                       |

## Interfaces

| Interface   | What it is                                                                                                       |
| ----------- | ---------------------------------------------------------------------------------------------------------------- |
| Phone app   | Live desktop view + touch/keyboard input                                                                         |
| Desktop app | Companion app with QR pairing                                                                                    |
| Server CLI  | `open-deck-server` with `--port`, `--fps`, `--quality`, …                                                        |
| Protocol    | Documented WebSocket + JSON ([PROTOCOL.md](https://github.com/hieudoanm/open.deck/blob/master/docs/PROTOCOL.md)) |

## Platforms

- **Desktop server:** Windows, macOS, Linux
- **Phone client:** Android, iOS
