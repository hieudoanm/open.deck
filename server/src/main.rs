//! open-deck-server: streams the primary monitor to OpenDeck mobile clients
//! and injects their input back into the OS.

mod capture;
mod input;
mod protocol;

use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use std::time::Duration;

use anyhow::{Context, Result};
use axum::{
    extract::{
        ws::{Message, WebSocket, WebSocketUpgrade},
        Query, State,
    },
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::get,
    Router,
};
use clap::Parser;
use futures_util::{SinkExt, StreamExt};
use rand::distr::{Alphanumeric, SampleString};
use tokio::sync::{broadcast, mpsc};
use tower_http::cors::CorsLayer;
use tracing::{info, warn};

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
}

struct AppState {
    token: String,
    frames: broadcast::Sender<Arc<Frame>>,
    monitor: MonitorInfo,
    fps: u32,
    input_tx: mpsc::UnboundedSender<ClientMessage>,
    clients: Arc<AtomicUsize>,
}

#[derive(serde::Serialize)]
struct Status {
    clients: usize,
    desktop_width: u32,
    desktop_height: u32,
    fps: u32,
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

    let state = Arc::new(AppState {
        token: token.clone(),
        frames,
        monitor,
        fps: args.fps,
        input_tx,
        clients: Arc::new(AtomicUsize::new(0)),
    });

    let app = Router::new()
        .route("/health", get(|| async { "ok" }))
        .route("/status", get(status_handler))
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
    println!("===============================");
    println!();
    info!(%addr, "listening");

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;
    Ok(())
}

async fn ws_handler(
    ws: WebSocketUpgrade,
    Query(params): Query<HashMap<String, String>>,
    State(state): State<Arc<AppState>>,
) -> Response {
    let provided = params.get("token").cloned().unwrap_or_default();
    if provided != state.token {
        warn!("rejected WS client: bad token");
        return (StatusCode::UNAUTHORIZED, "invalid pairing token").into_response();
    }
    ws.on_upgrade(move |socket| handle_socket(socket, state))
}

async fn status_handler(State(state): State<Arc<AppState>>) -> axum::Json<Status> {
    axum::Json(Status {
        clients: state.clients.load(Ordering::Relaxed),
        desktop_width: state.monitor.width,
        desktop_height: state.monitor.height,
        fps: state.fps,
    })
}

/// Messages the sender half can push to the client.
enum Outbound {
    Json(String),
}

async fn handle_socket(socket: WebSocket, state: Arc<AppState>) {
    state.clients.fetch_add(1, Ordering::Relaxed);
    let _guard = ClientGuard(state.clients.clone());
    let (mut sink, mut stream) = socket.split();
    let mut frames_rx = state.frames.subscribe();
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
            }
        }
    });

    // Receiver loop: client text frames → input thread / JSON replies.
    while let Some(Ok(msg)) = stream.next().await {
        match msg {
            Message::Text(text) => match serde_json::from_str::<ClientMessage>(&text) {
                Ok(ClientMessage::Ping) => {
                    if let Ok(pong) = serde_json::to_string(&ServerMessage::Pong) {
                        let _ = out_tx.send(Outbound::Json(pong));
                    }
                }
                Ok(m) => {
                    if state.input_tx.send(m).is_err() {
                        warn!("input thread gone");
                        break;
                    }
                }
                Err(e) => {
                    warn!("bad client message: {e}");
                }
            },
            Message::Close(_) => break,
            _ => {}
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
