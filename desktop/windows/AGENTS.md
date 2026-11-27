# AGENTS.md — desktop/windows

OpenDeck Windows companion: WinUI 3 (Windows App SDK 1.6), .NET 8,
`net8.0-windows10.0.19041.0`, unpackaged (`WindowsPackageType=None`).

## Commands

```powershell
cd desktop/windows
dotnet build OpenDeckWinUI.sln -c Release
dotnet build OpenDeckWinUI/OpenDeckWinUI.csproj -c Release
```

Windows-only — cannot be built on macOS/Linux CI agents.

## Structure

- `OpenDeckWinUI.sln` — x64 solution wrapping the single project.
- `OpenDeckWinUI/OpenDeckWinUI.csproj` — `UseWinUI=true`, WAP SDK
  `1.6.241114003`, `QRCoder` `1.6.0`, RIDs win-x86/x64/arm64.
- `App.xaml` / `App.xaml.cs` — `Application`; `OnLaunched` creates and
  activates `MainWindow`.
- `MainWindow.xaml` / `MainWindow.xaml.cs` — all logic: `FindServerBinary()`
  (app dir → repo `server/target/release` → `PATH`), `Process` spawn with
  `--port`, stdout reader parsing the `Pairing token` banner line,
  `ShowQr()` via QRCoder, `LanIp()` via UDP-connect trick, Start/Stop toggle.
- `app.manifest` — DPI awareness / longPathAware settings.

## Conventions

- C# with nullable + implicit usings enabled; WinUI 3 XAML + code-behind (no
  MVVM framework — keep it that way unless a second view appears).
- All UI updates from background work go through
  `DispatcherQueue.TryEnqueue`.
- The server stdout banner (`Pairing token : …`) is a contract with
  `open-deck-server` — keep parsing tolerant.
- QR payload uses the `opendeck://connect?host=…&port=…&token=…` scheme;
  changing it requires updating the phone apps' deep-link handling.
- Never commit `bin/`, `obj/`, or `.vs/`.
