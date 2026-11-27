# OpenDeck for Windows

WinUI 3 companion for `open-deck-server`: start/stop the server, enter the
port, copy the pairing token, and show a QR code for the phone app.

## Requirements

- Windows 10 1809+ (target `net8.0-windows10.0.19041.0`, min 17763)
- .NET 8 SDK
- `open-deck-server.exe` — next to the app, on `PATH`, or in the repo's
  `server/target/release/` layout

## Build & run

```powershell
cd desktop/windows
dotnet build OpenDeckWinUI.sln -c Release
.\OpenDeckWinUI\bin\x64\Release\net8.0-windows10.0.19041.0\win-x64\OpenDeckWinUI.exe
```

Unpackaged (`WindowsPackageType=None`) — runs without MSIX install.
Platforms: x86, x64, ARM64.

## What it does

- **Server launch** (`MainWindow.xaml.cs`) — finds `open-deck-server.exe`
  (app dir → repo dev path → `PATH`), spawns it with `--port`, redirects
  stdout, parses the `Pairing token` line, and shows token + QR.
- **QR pairing** — `QRCoder` renders `opendeck://connect?host=<LAN-IP>&port=…&token=…`
  (`LanIp()` uses a UDP socket trick to pick the primary interface address).
- **Status** — token `TextBox`, port `NumberBox`, Start/Stop toggle button,
  status text; server `Exited` event resets the UI.

## Layout

- `OpenDeckWinUI.sln` + `OpenDeckWinUI/` — single-project solution.
- `OpenDeckWinUI.csproj` — `UseWinUI`, `Microsoft.WindowsAppSDK` 1.6,
  `QRCoder` 1.6, unpackaged.
- `App.xaml(.cs)` — `Application` entry, single `MainWindow`.
- `MainWindow.xaml(.cs)` — UI + all server/process/QR logic (~180 lines).
- `app.manifest` — application manifest (long-path aware, etc.).
