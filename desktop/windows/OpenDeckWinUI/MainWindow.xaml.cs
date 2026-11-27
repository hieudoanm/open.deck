using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Text;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media.Imaging;
using QRCoder;
using Windows.ApplicationModel.DataTransfer;
using Windows.Storage.Streams;
using Windows.UI;

namespace OpenDeckWinUI;

public sealed partial class MainWindow : Window
{
    private Process? _server;
    private CancellationTokenSource? _readCts;
    private string? _token;

    public MainWindow()
    {
        InitializeComponent();
        ExtendsContentIntoTitleBar = true;
    }

    private void ToggleButton_Click(object sender, RoutedEventArgs e)
    {
        if (_server is null) StartServer();
        else StopServer();
    }

    private void StartServer()
    {
        var binary = FindServerBinary();
        if (binary is null)
        {
            StatusText.Text = "open-deck-server.exe not found next to the app or on PATH";
            return;
        }

        var port = PortBox.Value is double v ? (int)v : 47821;
        var psi = new ProcessStartInfo(binary)
        {
            Arguments = $"--port {port}",
            RedirectStandardOutput = true,
            UseShellExecute = false,
            CreateNoWindow = true,
        };

        _server = new Process { StartInfo = psi, EnableRaisingEvents = true };
        _server.Exited += (_, _) => DispatcherQueue.TryEnqueue(() =>
        {
            _server = null;
            UpdateRunningUi(false, "Exited");
        });

        try
        {
            _server.Start();
        }
        catch (Exception ex)
        {
            StatusText.Text = $"Failed to start: {ex.Message}";
            _server = null;
            return;
        }

        PortBox.IsEnabled = false;
        UpdateRunningUi(true, $"Running (pid {_server.Id})");
        ToggleButton.Content = "Stop server";

        _readCts = new CancellationTokenSource();
        _ = ReadStdoutAsync(_server.StandardOutput, _readCts.Token);
    }

    private async Task ReadStdoutAsync(StreamReader reader, CancellationToken ct)
    {
        try
        {
            while (!ct.IsCancellationRequested)
            {
                var line = await reader.ReadLineAsync(ct);
                if (line is null) break;
                var token = ParseToken(line);
                if (token is not null)
                {
                    _token = token;
                    DispatcherQueue.TryEnqueue(() =>
                    {
                        TokenBox.Text = token;
                        ShowQr(token);
                    });
                }
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
        ToggleButton.Content = "Start server";
        PortBox.IsEnabled = true;
        TokenBox.Text = "";
        QrImage.Source = null;
    }

    private void UpdateRunningUi(bool running, string status)
    {
        StatusText.Text = status;
        ToggleButton.Content = running ? "Stop server" : "Start server";
    }

    private void CopyButton_Click(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrEmpty(_token)) return;
        var dp = new DataPackage();
        dp.SetText(_token);
        Clipboard.SetContent(dp);
    }

    private void ShowQr(string token)
    {
        var port = PortBox.Value is double v ? (int)v : 47821;
        var payload = $"opendeck://connect?host={LanIp()}&port={port}&token={token}";
        using var gen = new QRCodeGenerator();
        using var data = gen.CreateQrCode(payload, QRCodeGenerator.ECCLevel.M);
        using var qr = new PngByteQRCode(data);
        var bytes = qr.GetGraphic(10);

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
        var candidates = new List<string>
        {
            Path.Combine(AppContext.BaseDirectory, "open-deck-server.exe"),
            Path.Combine(AppContext.BaseDirectory, "..\\..\\..\\..\\..\\server\\target\\release\\open-deck-server.exe"),
        };
        foreach (var dir in (Environment.GetEnvironmentVariable("PATH") ?? "")
                     .Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries))
        {
            candidates.Add(Path.Combine(dir, "open-deck-server.exe"));
        }
        return candidates.FirstOrDefault(File.Exists);
    }

    private static string LanIp()
    {
        try
        {
            using var socket = new Socket(AddressFamily.InterNetwork, SocketType.Dgram, ProtocolType.Udp);
            socket.Connect("192.0.2.1", 80); // TEST-NET-1, no packets sent
            if (socket.LocalEndPoint is IPEndPoint ep) return ep.Address.ToString();
        }
        catch { }
        return "THIS_PC";
    }
}
