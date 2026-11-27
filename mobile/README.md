# mobile/

Phone clients for OpenDeck — the "Stream Deck" side of the product. Both apps
speak the same WebSocket protocol as `open-deck-server` (`docs/PROTOCOL.md`):
live JPEG desktop frames in, JSON mouse/keyboard messages out.

| Directory  | Platform | Stack                                      |
| ---------- | -------- | ------------------------------------------ |
| `android/` | Android  | Kotlin, Jetpack Compose, OkHttp            |
| `ios/`     | iOS      | SwiftUI, URLSessionWebSocketTask, xcodegen |

See each subdirectory's README for build instructions.
