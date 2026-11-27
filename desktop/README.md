# desktop/

Desktop companions for OpenDeck. Each app locates (or bundles) the
`open-deck-server` binary from `server/`, launches it, and shows the pairing
token — usually as a QR code the phone app scans.

| Directory  | Platform  | Stack                        |
| ---------- | --------- | ---------------------------- |
| `macos/`   | macOS 14+ | SwiftUI (SwiftPM + xcodegen) |
| `linux/`   | Linux     | Rust + GTK4/libadwaita       |
| `windows/` | Windows   | WinUI 3 (.NET 8, unpackaged) |

The actual streaming/input logic lives in `server/`; these apps are
launchers + pairing UX. See each subdirectory's README for build instructions.
