//! open-deck-server: streams the primary monitor to OpenDeck mobile clients
//! and injects their input back into the OS.

mod actions;
mod capture;
mod clipboard;
mod hostinfo;
mod input;
mod protocol;
mod stats;

use std::collections::HashMap;
use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use anyhow::{Context, Result};
use axum::{
    extract::{
        ws::{Message, WebSocket, WebSocketUpgrade},
        ConnectInfo, Path as AxumPath, Query, State,
    },
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::{get, post},
    Json, Router,
};
use clap::Parser;
use futures_util::{SinkExt, StreamExt};
use rand::distr::{Alphanumeric, SampleString};
use serde::Deserialize;
use tokio::sync::{broadcast, mpsc, oneshot};
use tower_http::cors::CorsLayer;
use tracing::{info, warn};

use actions::ActionEngine;
use capture::{spawn_capture, CaptureConfig, MonitorInfo};
use protocol::{ClientMessage, Frame, ServerMessage};

#[derive(Parser)]
#[command(name = "open-deck-server", about = "OpenDeck companion server")]
struct Args {
    /// Port to listen on.
    #[arg(long, default_value_t = 47821)]
    port: u16,

    /// Stream frames per second.
    #[arg(long, default_value_t = 15)]
    fps: u32,

    /// JPEG quality 1-100.
    #[arg(long, default_value_t = 70)]
    quality: u8,

    /// Max stream width in pixels (height scales to keep aspect).
    #[arg(long, default_value_t = 1280)]
    max_width: u32,

    /// Pairing token. Generated randomly if not provided
    /// (also read from OPENSDECK_TOKEN).
    #[arg(long, env = "OPENSDECK_TOKEN")]
    token: Option<String>,

    /// Bind address.
    #[arg(long, default_value = "0.0.0.0")]
    bind: String,

    /// Path to a JSON actions file. Defaults to
    /// $XDG_CONFIG_HOME/opendeck/actions.json (or ~/.config/opendeck/actions.json).
    #[arg(long)]
    actions: Option<PathBuf>,
}

/// A connected client device, surfaced via GET /devices.
struct Device {
    id: u64,
    name: String,
    addr: SocketAddr,
    connected_at: u64,
    kick: oneshot::Sender<()>,
}

impl Device {
    fn info(&self) -> DeviceInfo {
        DeviceInfo {
            id: self.id,
            name: self.name.clone(),
            addr: self.addr.to_string(),
            connected_at: self.connected_at,
        }
    }
}

#[derive(serde::Serialize)]
struct DeviceInfo {
    id: u64,
    name: String,
    addr: String,
    connected_at: u64,
}

struct AppState {
    token: String,
    frames: broadcast::Sender<Arc<Frame>>,
    monitor: MonitorInfo,
    fps: u32,
    input_tx: mpsc::UnboundedSender<ClientMessage>,
    clients: Arc<AtomicUsize>,
    devices: Arc<Mutex<HashMap<u64, Device>>>,
    next_id: AtomicU64,
    actions: Arc<ActionEngine>,
    stats: broadcast::Sender<ServerMessage>,
    clipboard: clipboard::SharedClipboard,
}

#[derive(serde::Serialize)]
struct Status {
    clients: usize,
    desktop_width: u32,
    desktop_height: u32,
    fps: u32,
}

#[derive(Deserialize)]
struct RunActionRequest {
    name: String,
}

#[derive(Deserialize)]
struct KillRequest {
    pid: u32,
    #[serde(default)]
    force: bool,
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| "info".into()),
        )
        .init();

    let args = Args::parse();
    let token = args.token.unwrap_or_else(|| {
        Alphanumeric
            .sample_string(&mut rand::rng(), 8)
            .to_uppercase()
    });

    let (frames, monitor) = spawn_capture(CaptureConfig {
        fps: args.fps,
        quality: args.quality.clamp(1, 100),
        max_width: args.max_width,
        max_height: args.max_width * 2,
    })?;

    let input_tx = input::spawn_input_thread();
    let actions = Arc::new(ActionEngine::load(args.actions.as_deref())?);
    info!(count = actions.list().len(), "actions loaded");
    let stats_tx = stats::spawn_stats();
    let clipboard_state = clipboard::new_state();
    clipboard::spawn_poller(clipboard_state.clone());

    let state = Arc::new(AppState {
        token: token.clone(),
        frames,
        monitor,
        fps: args.fps,
        input_tx,
        clients: Arc::new(AtomicUsize::new(0)),
        devices: Arc::new(Mutex::new(HashMap::new())),
        next_id: AtomicU64::new(1),
        actions,
        stats: stats_tx,
        clipboard: clipboard_state,
    });

    let app = Router::new()
        .route("/", get(web_index_handler))
        .route("/{*path}", get(web_asset_handler))
        .route("/health", get(|| async { "ok" }))
        .route("/status", get(status_handler))
        .route("/devices", get(devices_handler))
        .route("/devices/{id}/disconnect", post(disconnect_handler))
        .route("/actions", get(actions_list_handler))
        .route("/actions/run", post(actions_run_handler))
        .route("/ports", get(ports_handler))
        .route("/ports/kill", post(ports_kill_handler))
        .route("/apps", get(apps_handler))
        .route("/clipboard", get(clipboard_get_handler))
        .route("/clipboard", post(clipboard_write_handler))
        .route("/clipboard", axum::routing::delete(clipboard_clear_handler))
        .route("/ws", get(ws_handler))
        .layer(CorsLayer::permissive())
        .with_state(state);

    let addr: SocketAddr = format!("{}:{}", args.bind, args.port)
        .parse()
        .context("invalid bind address")?;

    // Print pairing info prominently — this is what the user types into
    // the phone/desktop app (or encodes as a QR code).
    println!();
    println!("=== OpenDeck server is running ===");
    println!("  Pairing token : {token}");
    println!("  WebSocket URL : ws://<this-pc>:{}", args.port);
    println!("  Path          : /ws?token=<token>");
    println!(
        "  Monitor       : {}x{} @ {}fps",
        monitor.width, monitor.height, args.fps
    );
    println!("  Actions       : GET /actions, POST /actions/run");
    println!("===============================");
    if let Some(ip) = lan_ip() {
        let url = format!(
            "http://{ip}:{}/?host={ip}&port={}&token={token}",
            args.port, args.port
        );
        println!();
        println!("  Web UI (scan QR on your phone): {url}");
        if let Ok(code) = qrcode::QrCode::new(url.as_bytes()) {
            println!(
                "{}",
                code.render::<qrcode::render::unicode::Dense1x2>().build()
            );
        }
    }
    println!();
    info!(%addr, "listening");

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(
        listener,
        app.into_make_service_with_connect_info::<SocketAddr>(),
    )
    .await?;
    Ok(())
}

/// Browser remote-desktop client, compiled into the binary so a single
/// The Vite build output in `server/web/` is embedded into the binary, so a
/// single `open-deck-server` executable serves both the API and the web UI.
static WEB_DIR: include_dir::Dir<'_> = include_dir::include_dir!("$CARGO_MANIFEST_DIR/web");

fn web_content_type(path: &str) -> &'static str {
    match path.rsplit('.').next() {
        Some("html") => "text/html; charset=utf-8",
        Some("js" | "mjs") => "text/javascript; charset=utf-8",
        Some("css") => "text/css; charset=utf-8",
        Some("webmanifest") => "application/manifest+json",
        Some("json") => "application/json",
        Some("png") => "image/png",
        Some("svg") => "image/svg+xml",
        Some("ico") => "image/x-icon",
        Some("mp4") => "video/mp4",
        Some("woff2") => "font/woff2",
        _ => "application/octet-stream",
    }
}

fn serve_web_file(rel: &str) -> Response {
    match WEB_DIR.get_file(rel) {
        Some(file) => {
            let ct = web_content_type(file.path().to_string_lossy().as_ref());
            ([(axum::http::header::CONTENT_TYPE, ct)], file.contents()).into_response()
        }
        None => StatusCode::NOT_FOUND.into_response(),
    }
}

async fn web_index_handler() -> Response {
    serve_web_file("index.html")
}

async fn web_asset_handler(AxumPath(path): AxumPath<String>) -> Response {
    let rel = path.trim_start_matches('/');
    if WEB_DIR.get_file(rel).is_some() {
        return serve_web_file(rel);
    }
    // SPA fallback: extensionless paths get the app shell.
    if !rel.contains('.') {
        return serve_web_file("index.html");
    }
    StatusCode::NOT_FOUND.into_response()
}

async fn status_handler(State(state): State<Arc<AppState>>) -> axum::Json<Status> {
    axum::Json(Status {
        clients: state.clients.load(Ordering::Relaxed),
        desktop_width: state.monitor.width,
        desktop_height: state.monitor.height,
        fps: state.fps,
    })
}

async fn devices_handler(State(state): State<Arc<AppState>>) -> Json<Vec<DeviceInfo>> {
    let devices = state.devices.lock().unwrap();
    Json(devices.values().map(Device::info).collect::<Vec<_>>())
}

async fn disconnect_handler(
    AxumPath(id): AxumPath<u64>,
    State(state): State<Arc<AppState>>,
) -> Response {
    let kick = {
        let mut devices = state.devices.lock().unwrap();
        devices.remove(&id).map(|d| d.kick)
    };
    match kick {
        Some(tx) => {
            let _ = tx.send(());
            (StatusCode::OK, "disconnected").into_response()
        }
        None => (StatusCode::NOT_FOUND, "unknown device").into_response(),
    }
}

async fn actions_list_handler(
    State(state): State<Arc<AppState>>,
) -> Json<Vec<actions::ActionInfo>> {
    Json(state.actions.list())
}

async fn actions_run_handler(
    State(state): State<Arc<AppState>>,
    Query(params): Query<HashMap<String, String>>,
    Json(req): Json<RunActionRequest>,
) -> Response {
    // Actions can run arbitrary commands — require the pairing token.
    let provided = params.get("token").cloned().unwrap_or_default();
    if provided != state.token {
        return (StatusCode::UNAUTHORIZED, "invalid pairing token").into_response();
    }
    match state.actions.run(&req.name, &state.input_tx) {
        Ok(()) => (StatusCode::OK, format!("ran '{}'", req.name)).into_response(),
        Err(e) => (StatusCode::BAD_REQUEST, format!("{e:#}")).into_response(),
    }
}

async fn ports_handler() -> Json<Vec<hostinfo::PortEntry>> {
    let ports = tokio::task::spawn_blocking(hostinfo::list_ports)
        .await
        .unwrap_or_default();
    Json(ports)
}

async fn apps_handler() -> Json<Vec<hostinfo::AppEntry>> {
    let apps = tokio::task::spawn_blocking(hostinfo::list_apps)
        .await
        .unwrap_or_default();
    Json(apps)
}

/// Kill is destructive — require the pairing token (same pattern as
/// `/actions/run`).
async fn ports_kill_handler(
    State(state): State<Arc<AppState>>,
    Query(params): Query<HashMap<String, String>>,
    Json(req): Json<KillRequest>,
) -> Response {
    let provided = params.get("token").cloned().unwrap_or_default();
    if provided != state.token {
        return (StatusCode::UNAUTHORIZED, "invalid pairing token").into_response();
    }
    match tokio::task::spawn_blocking(move || hostinfo::kill_process(req.pid, req.force)).await {
        Ok(Ok(())) => (StatusCode::OK, "terminated").into_response(),
        Ok(Err(e)) => (StatusCode::BAD_REQUEST, e).into_response(),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    }
}

/// Clipboard contents are sensitive — token required on all three verbs.
fn clipboard_token_ok(state: &AppState, params: &HashMap<String, String>) -> bool {
    params.get("token").map(String::as_str) == Some(state.token.as_str())
}

async fn clipboard_get_handler(
    State(state): State<Arc<AppState>>,
    Query(params): Query<HashMap<String, String>>,
) -> Response {
    if !clipboard_token_ok(&state, &params) {
        return (StatusCode::UNAUTHORIZED, "invalid pairing token").into_response();
    }
    let items = state
        .clipboard
        .lock()
        .map(|g| g.snapshot())
        .unwrap_or_default();
    Json(items).into_response()
}

async fn clipboard_write_handler(
    State(state): State<Arc<AppState>>,
    Query(params): Query<HashMap<String, String>>,
    Json(req): Json<clipboard::ClipboardWrite>,
) -> Response {
    if !clipboard_token_ok(&state, &params) {
        return (StatusCode::UNAUTHORIZED, "invalid pairing token").into_response();
    }
    let write_text = req.content.clone();
    let record_text = req.content.clone();
    match tokio::task::spawn_blocking(move || clipboard::write_clipboard_text_pub(&write_text))
        .await
    {
        Ok(Ok(())) => {
            if let Ok(mut guard) = state.clipboard.lock() {
                guard.record(record_text);
            }
            (StatusCode::OK, "copied").into_response()
        }
        Ok(Err(e)) => (StatusCode::BAD_REQUEST, e).into_response(),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    }
}

async fn clipboard_clear_handler(
    State(state): State<Arc<AppState>>,
    Query(params): Query<HashMap<String, String>>,
) -> Response {
    if !clipboard_token_ok(&state, &params) {
        return (StatusCode::UNAUTHORIZED, "invalid pairing token").into_response();
    }
    if let Ok(mut guard) = state.clipboard.lock() {
        guard.clear();
    }
    (StatusCode::OK, "cleared").into_response()
}

async fn ws_handler(
    ws: WebSocketUpgrade,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    Query(params): Query<HashMap<String, String>>,
    State(state): State<Arc<AppState>>,
) -> Response {
    let provided = params.get("token").cloned().unwrap_or_default();
    if provided != state.token {
        warn!("rejected WS client: bad token");
        return (StatusCode::UNAUTHORIZED, "invalid pairing token").into_response();
    }
    ws.on_upgrade(move |socket| handle_socket(socket, state, addr))
}

/// Messages the sender half can push to the client.
enum Outbound {
    Json(String),
}

fn now_unix() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

async fn handle_socket(socket: WebSocket, state: Arc<AppState>, addr: SocketAddr) {
    state.clients.fetch_add(1, Ordering::Relaxed);
    let _guard = ClientGuard(state.clients.clone());

    let id = state.next_id.fetch_add(1, Ordering::Relaxed);
    let (kick_tx, mut kick_rx) = oneshot::channel::<()>();
    {
        let mut devices = state.devices.lock().unwrap();
        devices.insert(
            id,
            Device {
                id,
                name: String::new(),
                addr,
                connected_at: now_unix(),
                kick: kick_tx,
            },
        );
    }
    let _device_guard = DeviceGuard {
        devices: state.devices.clone(),
        id,
    };

    let (mut sink, mut stream) = socket.split();
    let mut frames_rx = state.frames.subscribe();
    let mut stats_rx = state.stats.subscribe();
    let (out_tx, mut out_rx) = mpsc::unbounded_channel::<Outbound>();

    // Sender task: hello → frames + any JSON replies (pong, errors).
    let sender_state = state.clone();
    let sender = tokio::spawn(async move {
        // Wait briefly for the first frame so `hello` carries real stream dims.
        let first = tokio::time::timeout(Duration::from_secs(3), frames_rx.recv()).await;
        let (sw, sh) = match &first {
            Ok(Ok(f)) => (f.width, f.height),
            _ => (0, 0),
        };
        let hello = ServerMessage::Hello {
            version: 1,
            name: "open-deck-server".into(),
            desktop_width: sender_state.monitor.width,
            desktop_height: sender_state.monitor.height,
            stream_width: sw,
            stream_height: sh,
            fps: sender_state.fps,
            max_fps: sender_state.fps,
        };
        if let Ok(text) = serde_json::to_string(&hello) {
            if sink.send(Message::Text(text.into())).await.is_err() {
                return;
            }
        }
        if let Ok(Ok(f)) = first {
            if sink
                .send(Message::Binary(f.jpeg.to_vec().into()))
                .await
                .is_err()
            {
                return;
            }
        }
        loop {
            tokio::select! {
                biased;
                out = out_rx.recv() => {
                    match out {
                        Some(Outbound::Json(text)) => {
                            if sink.send(Message::Text(text.into())).await.is_err() { break; }
                        }
                        None => break,
                    }
                }
                frame = frames_rx.recv() => {
                    match frame {
                        Ok(f) => {
                            if sink.send(Message::Binary(f.jpeg.to_vec().into())).await.is_err() { break; }
                        }
                        Err(broadcast::error::RecvError::Lagged(_)) => continue,
                        Err(broadcast::error::RecvError::Closed) => break,
                    }
                }
                stats = stats_rx.recv() => {
                    match stats {
                        Ok(m) => {
                            if let Ok(text) = serde_json::to_string(&m) {
                                if sink.send(Message::Text(text.into())).await.is_err() { break; }
                            }
                        }
                        Err(broadcast::error::RecvError::Lagged(_)) => continue,
                        Err(broadcast::error::RecvError::Closed) => {}
                    }
                }
            }
        }
    });

    // Receiver loop: client text frames → registry / input thread / replies.
    loop {
        tokio::select! {
            biased;
            _ = &mut kick_rx => {
                info!(id, "device disconnected by admin");
                break;
            }
            msg = stream.next() => {
                match msg {
                    Some(Ok(Message::Text(text))) => {
                        match serde_json::from_str::<ClientMessage>(&text) {
                            Ok(ClientMessage::Ping) => {
                                if let Ok(pong) = serde_json::to_string(&ServerMessage::Pong) {
                                    let _ = out_tx.send(Outbound::Json(pong));
                                }
                            }
                            Ok(ClientMessage::RunAction { name }) => {
                                if let Err(e) = state.actions.run(&name, &state.input_tx) {
                                    warn!("action '{name}' failed: {e:#}");
                                }
                            }
                            Ok(m) => {
                                if let ClientMessage::Hello { name: Some(n), .. } = &m {
                                    let mut devices = state.devices.lock().unwrap();
                                    if let Some(d) = devices.get_mut(&id) {
                                        d.name = n.clone();
                                    }
                                }
                                if state.input_tx.send(m).is_err() {
                                    warn!("input thread gone");
                                    break;
                                }
                            }
                            Err(e) => {
                                warn!("bad client message: {e}");
                            }
                        }
                    }
                    Some(Ok(Message::Close(_))) | None => break,
                    Some(Ok(_)) => {}
                    Some(Err(e)) => {
                        warn!("ws error: {e}");
                        break;
                    }
                }
            }
        }
    }

    sender.abort();
    info!("client disconnected");
}

struct ClientGuard(Arc<AtomicUsize>);

impl Drop for ClientGuard {
    fn drop(&mut self) {
        self.0.fetch_sub(1, Ordering::Relaxed);
    }
}

struct DeviceGuard {
    devices: Arc<Mutex<HashMap<u64, Device>>>,
    id: u64,
}

impl Drop for DeviceGuard {
    fn drop(&mut self) {
        self.devices.lock().unwrap().remove(&self.id);
    }
}

/// Best-effort LAN IPv4 via the UDP-connect trick (no packets are sent).
fn lan_ip() -> Option<String> {
    let socket = std::net::UdpSocket::bind("0.0.0.0:0").ok()?;
    socket.connect("192.0.2.1:80").ok()?; // TEST-NET-1
    let ip = socket.local_addr().ok()?.ip().to_string();
    if ip.starts_with("127.") {
        None
    } else {
        Some(ip)
    }
}
