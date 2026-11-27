# Desktop companion — Linux

`opendeck-linux` is the GTK4 + libadwaita companion for `open-deck-server`. It
finds the server binary, starts and stops it, shows the pairing QR code, and
reports live connection status.

## Requirements

- A Linux desktop with GTK4 and libadwaita (GNOME 43+ era or later)
- Rust stable (to build from source)
- Development packages for GTK4/libadwaita — on Debian/Ubuntu:

  ```sh
  sudo apt install libgtk-4-dev libadwaita-1-dev
  ```

## Build

```sh
cd desktop/linux
cargo build --release
```

## Run

```sh
./target/release/opendeck-linux
```

You can also set `OPENSDECK_SERVER=/path/to/open-deck-server` if the binary
isn't where the app expects it (see "Server discovery" below).

## Using the app

The window is a single adwaita page with three sections:

- **Status** — whether the server is running, the LAN IP, the bound port,
  connected phone clients, and the captured monitor resolution. These values
  refresh automatically every couple of seconds.
- **Pairing** — the pairing token (copyable to clipboard) and a QR code encoding
  `opendeck://connect?host=<LAN-IP>&port=<port>&token=<token>`.
- **Server settings** — port, fps, quality and max stream width used when the
  server is launched, plus a Start/Stop toggle.

### First run

1. Build `open-deck-server` once (`cd server && cargo build --release`) or point
   the app at an existing binary (see below).
2. Launch `opendeck-linux`. It searches for `open-deck-server` in this order:
   `$OPENSDECK_SERVER` → the app's own directory → `PATH` → the repo's
   `server/target/{release,debug}/` layout (walks up 6 directories).
3. Click **Start server**. The app scrapes the `Pairing token` and `Monitor`
   lines from the server's stdout and shows them in the Pairing section.
4. Scan the QR code with the phone app (camera scan, or write the same URI to an
   NFC tag). The phone's connect form fills in automatically — tap **Connect**.

### Day-to-day

- **Stop** kills the server child process; closing the window does too.
- The server settings only apply to the _next_ launch — stop and start again
  after changing port/fps/quality/max-width.
- If the phone disconnects, the client count in Status drops to zero; the
  pairing token stays the same until the server restarts.

## Troubleshooting

- _Server won't start / "binary not found"_ — set `OPENSDECK_SERVER` to the
  absolute path of `open-deck-server`, or build it under `server/target/`.
- _QR doesn't pair_ — the phone must be on the same LAN; the QR embeds the PC's
  primary IPv4 (UDP-connect trick), so a VPN or multiple interfaces can pick the
  wrong address. Enter the host manually in that case.
- _Status stuck at 0 clients_ — the app polls `GET /status` on
  `127.0.0.1:<port>`; if you changed the port setting, restart the server so the
  app polls the right one.
