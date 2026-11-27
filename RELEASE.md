## OpenDeck — latest build

OpenDeck turns an old phone into a "Stream Deck"-style companion for your PC:
a Rust server streams the desktop over WebSocket and injects touch/keyboard
input back into the session.

### Download

- `open-deck-server-*` — companion server binaries for Linux, macOS, and
  Windows.
- `mobile-android-open-deck.apk` — Android client for sideloading.

Desktop companion apps and the iOS client are built from source for now; see
[the README](https://github.com/hieudoanm/open.deck#readme) and
[the landing docs](https://hieudoanm.github.io/open.deck/docs/) for build
instructions.

### Quick start

```sh
open-deck-server --port 47821
```

Pair the phone with the LAN address and pairing token printed by the server:

```text
ws://<this-pc>:47821/ws?token=<token>
```

### Documentation

- [README](https://github.com/hieudoanm/open.deck#readme)
- [Protocol](https://github.com/hieudoanm/open.deck/blob/master/docs/PROTOCOL.md)
- [Landing site](https://hieudoanm.github.io/open.deck/)
