using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using Microsoft.UI.Xaml;
using Microsoft.UI;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using QRCoder;
using Windows.ApplicationModel.DataTransfer;
using Windows.Storage;
using Windows.Storage.Streams;
using Windows.UI;

namespace OpenDeckWinUI;

public sealed partial class MainWindow : Window
{
    private sealed class DeviceItem
    {
        public string Name { get; set; } = "";
        public string Addr { get; set; } = "";
        public long Id { get; set; }
    }

    private sealed class ActionItem
    {
        public string Name { get; set; } = "";
        public string Kind { get; set; } = "";
    }

    private Process? _server;
    private CancellationTokenSource? _readCts;
    private string? _token;
    private readonly HttpClient _http = new() { Timeout = TimeSpan.FromSeconds(3) };
    private readonly ObservableCollection<DeviceItem> _devices = new();
    private readonly ObservableCollection<ActionItem> _actions = new();
    private readonly ObservableCollection<string> _log = new();
    private Timer? _pollTimer;
    private string? _serverPath;

    public MainWindow()
    {
        InitializeComponent();
        ExtendsContentIntoTitleBar = true;
        DevicesList.ItemsSource = _devices;
        ActionsList.ItemsSource = _actions;
        LogList.ItemsSource = _log;
        LoadSettings();
        RefreshServerPath();
        BinaryText.Text = _serverPath ?? "not found";
        _pollTimer = new Timer(_ => DispatcherQueue.TryEnqueue(PollStatus), null,
            TimeSpan.FromSeconds(2), TimeSpan.FromSeconds(2));
        Closed += (_, _) =>
        {
            _pollTimer?.Dispose();
            RemoveTrayIcon();
        };
        QualitySlider.ValueChanged += (_, _) =>
            QualityText.Text = ((int)QualitySlider.Value).ToString();
        Activated += (_, e) =>
        {
            // First activation: the HWND exists, so the tray icon can be created.
            if (e.WindowActivationState != WindowActivationState.Deactivated && _trayHwnd == IntPtr.Zero)
                InitTrayIcon();
        };
    }

    // ---------- Settings persistence (ApplicationData.LocalSettings) ----------

    private static ApplicationDataContainer Settings =>
        ApplicationData.Current.LocalSettings;

    private void LoadSettings()
    {
        PortBox.Value = GetD("port", 47821);
        FpsBox.Value = GetD("fps", 15);
        QualitySlider.Value = GetD("quality", 70);
        QualityText.Text = ((int)QualitySlider.Value).ToString();
        WidthBox.Value = GetD("maxwidth", 1280);
        CustomTokenBox.Text = GetS("token", "");
    }

    private static double GetD(string key, double fallback) =>
        Settings.Values.TryGetValue(key, out var v) && v is double d ? d : fallback;

    private static string GetS(string key, string fallback) =>
        Settings.Values.TryGetValue(key, out var v) && v is string s ? s : fallback;

    private void SaveSettings()
    {
        Settings.Values["port"] = PortBox.Value;
        Settings.Values["fps"] = FpsBox.Value;
        Settings.Values["quality"] = (int)(QualitySlider.Value);
        Settings.Values["maxwidth"] = WidthBox.Value;
        Settings.Values["token"] = CustomTokenBox.Text ?? "";
    }

    private int Port => PortBox.Value is double p ? (int)p : 47821;
    private int Fps => FpsBox.Value is double f ? (int)f : 15;
    private int Quality => (int)(QualitySlider.Value);
    private int MaxWidth => WidthBox.Value is double w ? (int)w : 1280;

    // ---------- Server lifecycle ----------

    private void ToggleButton_Click(object sender, RoutedEventArgs e)
    {
        if (_server is null) StartServer();
        else StopServer();
    }

    private void RescanButton_Click(object sender, RoutedEventArgs e) => RefreshServerPath();

    private void RefreshServerPath()
    {
        _serverPath = FindServerBinary();
        BinaryText.Text = _serverPath ?? "not found — set OPENSDECK_SERVER or build server/";
        ToggleButton.IsEnabled = _serverPath is not null || _server is not null;
    }

    private void StartServer()
    {
        SaveSettings();
        var binary = _serverPath ?? FindServerBinary();
        if (binary is null)
        {
            AppendLog("error: open-deck-server not found");
            return;
        }
        var args = $"--port {Port} --fps {Fps} --quality {Quality} --max-width {MaxWidth}";
        var custom = CustomTokenBox.Text.Trim();
        if (custom.Length > 0) args += $" --token {custom}";

        var psi = new ProcessStartInfo(binary)
        {
            Arguments = args,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
        };
        _server = new Process { StartInfo = psi, EnableRaisingEvents = true };
        _server.Exited += (_, _) => DispatcherQueue.TryEnqueue(() =>
        {
            _server = null;
            UpdateRunningUi(false, "Exited");
            AppendLog("Server process exited");
        });
        try
        {
            _server.Start();
        }
        catch (Exception ex)
        {
            AppendLog($"error: failed to start: {ex.Message}");
            _server = null;
            return;
        }
        UpdateRunningUi(true, $"Running (pid {_server.Id})");
        AppendLog($"Launched {binary}");

        _readCts = new CancellationTokenSource();
        _ = ReadStreamAsync(_server.StandardOutput, isErr: false, _readCts.Token);
        _ = ReadStreamAsync(_server.StandardError, isErr: true, _readCts.Token);
    }

    private async Task ReadStreamAsync(StreamReader reader, bool isErr, CancellationToken ct)
    {
        try
        {
            while (!ct.IsCancellationRequested)
            {
                var line = await reader.ReadLineAsync(ct);
                if (line is null) break;
                var trimmed = line.Trim();
                if (trimmed.Length == 0) continue;
                var token = ParseToken(trimmed);
                if (token is not null)
                {
                    _token = token;
                    DispatcherQueue.TryEnqueue(() =>
                    {
                        TokenBox.Text = token;
                        ShowQr(token);
                    });
                }
                else if (trimmed.StartsWith("Monitor"))
                {
                    var v = trimmed[(trimmed.IndexOf(':') + 1)..].Trim();
                    DispatcherQueue.TryEnqueue(() => MonitorText.Text = v);
                }
                DispatcherQueue.TryEnqueue(() => AppendLog(trimmed));
            }
        }
        catch (OperationCanceledException) { }
    }

    private void StopServer()
    {
        _readCts?.Cancel();
        try { _server?.Kill(entireProcessTree: true); } catch { }
        _server?.Dispose();
        _server = null;
        UpdateRunningUi(false, "Stopped");
        _devices.Clear();
        ClientsText.Text = "0";
    }

    private void UpdateRunningUi(bool running, string status)
    {
        StatusText.Text = status;
        StateBadge.Text = running ? "Running" : "Stopped";
        StateDot.Fill = running
            ? new SolidColorBrush(Color.FromArgb(255, 34, 197, 94))
            : new SolidColorBrush(Color.FromArgb(255, 136, 136, 136));
        FooterDot.Fill = StateDot.Fill;
        ToggleButton.Content = running ? "Stop server" : "Start server";
        PortBox.IsEnabled = !running;
        FpsBox.IsEnabled = !running;
        QualitySlider.IsEnabled = !running;
        WidthBox.IsEnabled = !running;
        CustomTokenBox.IsEnabled = !running;
    }

    // ---------- Polling: /status, /devices, /actions ----------

    private async void PollStatus()
    {
        if (_server is null) return;
        try
        {
            var statusJson = await _http.GetStringAsync($"http://127.0.0.1:{Port}/status");
            using var doc = JsonDocument.Parse(statusJson);
            var root = doc.RootElement;
            ClientsText.Text = root.GetProperty("clients").GetInt32().ToString();
            var w = root.GetProperty("desktop_width").GetInt32();
            var h = root.GetProperty("desktop_height").GetInt32();
            MonitorText.Text = $"{w}x{h}";

            var devicesJson = await _http.GetStringAsync($"http://127.0.0.1:{Port}/devices");
            var list = JsonSerializer.Deserialize<List<DeviceItem>>(devicesJson,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? new();
            _devices.Clear();
            foreach (var d in list) _devices.Add(d);
            NoDevicesText.Visibility = _devices.Count == 0
                ? Visibility.Visible : Visibility.Collapsed;
        }
        catch { /* server not up yet */ }

        try
        {
            var actionsJson = await _http.GetStringAsync($"http://127.0.0.1:{Port}/actions");
            var list = JsonSerializer.Deserialize<List<ActionItem>>(actionsJson,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? new();
            if (_actions.Count != list.Count ||
                !_actions.Select(a => a.Name).SequenceEqual(list.Select(a => a.Name)))
            {
                _actions.Clear();
                foreach (var a in list) _actions.Add(a);
            }
            NoActionsText.Visibility = _actions.Count == 0
                ? Visibility.Visible : Visibility.Collapsed;
        }
        catch { }
    }

    private async void DisconnectButton_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: long id } && _token is not null)
        {
            try { await _http.PostAsync($"http://127.0.0.1:{Port}/devices/{id}/disconnect", null); }
            catch { }
        }
    }

    private async void ActionButton_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: string name } && _token is not null)
        {
            try
            {
                var resp = await _http.PostAsync(
                    $"http://127.0.0.1:{Port}/actions/run?token={Uri.EscapeDataString(_token)}",
                    new StringContent(JsonSerializer.Serialize(new { name }), Encoding.UTF8, "application/json"));
                AppendLog($"action '{name}': {(int)resp.StatusCode}");
            }
            catch (Exception ex) { AppendLog($"action '{name}' failed: {ex.Message}"); }
        }
    }

    // ---------- Pairing ----------

    private void CopyButton_Click(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrEmpty(_token)) return;
        var dp = new DataPackage { RequestedOperation = DataPackageOperation.Copy };
        dp.SetText(_token);
        Clipboard.SetContent(dp);
    }

    private void ShowQr(string token)
    {
        var payload = $"opendeck://connect?host={LanIp()}&port={Port}&token={token}";
        using var gen = new QRCodeGenerator();
        using var data = gen.CreateQrCode(payload, QRCodeGenerator.ECCLevel.M);
        using var qr = new PngByteQRCode(data);
        var bytes = qr.GetGraphic(8);
        var bitmap = new BitmapImage();
        using var stream = new InMemoryRandomAccessStream();
        using (var writer = new DataWriter(stream.GetOutputStreamAt(0)))
        {
            writer.WriteBytes(bytes);
            writer.StoreAsync().AsTask().Wait();
        }
        stream.FlushAsync().AsTask().Wait();
        bitmap.SetSourceAsync(stream).AsTask().Wait();
        QrImage.Source = bitmap;
    }

    // ---------- Log ----------

    private void AppendLog(string line)
    {
        _log.Add(line);
        if (_log.Count > 300) _log.RemoveAt(0);
        if (LogList.Items.Count > 0)
            LogList.ScrollIntoView(_log[^1]);
    }

    // ---------- System tray (background companion) ----------

    private IntPtr _trayHwnd;
    private IntPtr _trayWndProc;
    private IntPtr _trayOldProc;
    private bool _trayAdded;

    private void TrayButton_Click(object sender, RoutedEventArgs e) => AppWindow.Hide();

    private void ShowFromTray()
    {
        AppWindow.Show();
        Activate();
        SetForegroundWindow(_trayHwnd);
    }

    private void InitTrayIcon()
    {
        _trayHwnd = WinRT.Interop.WindowNative.GetWindowHandle(this);
        if (_trayHwnd == IntPtr.Zero) return;

        // Subclass the window proc to receive tray callback messages.
        _trayProcDelegate = new WndProcDelegate(TrayWndProc);
        _trayWndProc = Marshal.GetFunctionPointerForDelegate(_trayProcDelegate);
        _trayOldProc = SetWindowLongPtr(_trayHwnd, GWLP_WNDPROC, _trayWndProc);

        var data = new NOTIFYICONDATA
        {
            cbSize = (uint)Marshal.SizeOf<NOTIFYICONDATA>(),
            hWnd = _trayHwnd,
            uID = 1,
            uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP,
            uCallbackMessage = WM_TRAYICON,
            hIcon = LoadIcon(IntPtr.Zero, IDI_APPLICATION),
            szTip = "OpenDeck",
        };
        _trayAdded = Shell_NotifyIcon(NIM_ADD, ref data);
    }

    private void RemoveTrayIcon()
    {
        if (_trayAdded)
        {
            var data = new NOTIFYICONDATA { cbSize = (uint)Marshal.SizeOf<NOTIFYICONDATA>(), hWnd = _trayHwnd, uID = 1 };
            Shell_NotifyIcon(NIM_DELETE, ref data);
            _trayAdded = false;
        }
        if (_trayHwnd != IntPtr.Zero && _trayOldProc != IntPtr.Zero)
            SetWindowLongPtr(_trayHwnd, GWLP_WNDPROC, _trayOldProc);
    }

    // Kept alive for the lifetime of the window — the unmanaged window proc
    // calls into it.
    private WndProcDelegate? _trayProcDelegate;

    private delegate IntPtr WndProcDelegate(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);

    private IntPtr TrayWndProc(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam)
    {
        if (msg == WM_TRAYICON)
        {
            var mouse = (int)(lParam.ToInt64() & 0xFFFF);
            if (mouse is WM_LBUTTONUP or WM_LBUTTONDBLCLK or WM_RBUTTONUP)
                DispatcherQueue.TryEnqueue(ShowFromTray);
            return CallWindowProc(_trayOldProc, hWnd, msg, wParam, lParam);
        }
        return CallWindowProc(_trayOldProc, hWnd, msg, wParam, lParam);
    }

    // ---------- Win32 interop ----------

    private const int WM_TRAYICON = 0x8001; // WM_APP + 1
    private const int WM_LBUTTONUP = 0x0202;
    private const int WM_LBUTTONDBLCLK = 0x0203;
    private const int WM_RBUTTONUP = 0x0205;
    private const int GWLP_WNDPROC = -4;
    private const int NIM_ADD = 0x00000000;
    private const int NIM_DELETE = 0x00000002;
    private const int NIF_MESSAGE = 0x00000001;
    private const int NIF_ICON = 0x00000002;
    private const int NIF_TIP = 0x00000004;
    private static readonly IntPtr IDI_APPLICATION = (IntPtr)32512;

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct NOTIFYICONDATA
    {
        public uint cbSize;
        public IntPtr hWnd;
        public uint uID;
        public uint uFlags;
        public uint uCallbackMessage;
        public IntPtr hIcon;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string szTip;
        public uint dwState;
        public uint dwStateMask;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)]
        public string szInfo;
        public uint uTimeoutOrVersion;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
        public string szInfoTitle;
        public uint dwInfoFlags;
        public Guid guidItem;
        public IntPtr hBalloonIcon;
    }

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern bool Shell_NotifyIcon(int dwMessage, ref NOTIFYICONDATA lpdata);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr LoadIcon(IntPtr hInstance, IntPtr lpIconName);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtr")]
    private static extern IntPtr SetWindowLongPtr(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

    [DllImport("user32.dll", EntryPoint = "CallWindowProc")]
    private static extern IntPtr CallWindowProc(IntPtr lpPrevWndFunc, IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    // ---------- Helpers ----------

    private static string? ParseToken(string line)
    {
        const string marker = "Pairing token";
        var idx = line.IndexOf(marker, StringComparison.Ordinal);
        if (idx < 0) return null;
        var rest = line[(idx + marker.Length)..].TrimStart(':', ' ');
        var end = rest.IndexOfAny(new[] { ' ', '\t' });
        var token = end < 0 ? rest : rest[..end];
        return string.IsNullOrEmpty(token) ? null : token;
    }

    private static string? FindServerBinary()
    {
        var candidates = new List<string>();
        var env = Environment.GetEnvironmentVariable("OPENSDECK_SERVER");
        if (!string.IsNullOrEmpty(env)) candidates.Add(env);
        candidates.Add(Path.Combine(AppContext.BaseDirectory, "open-deck-server.exe"));
        foreach (var dir in (Environment.GetEnvironmentVariable("PATH") ?? "")
                     .Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries))
            candidates.Add(Path.Combine(dir, "open-deck-server.exe"));
        return candidates.FirstOrDefault(File.Exists);
    }

    private static string LanIp()
    {
        try
        {
            using var socket = new Socket(AddressFamily.InterNetwork, SocketType.Dgram, ProtocolType.Udp);
            socket.Connect("192.0.2.1", 80);
            if (socket.LocalEndPoint is IPEndPoint ep) return ep.Address.ToString();
        }
        catch { }
        return "THIS_PC";
    }
}
