//! open-deck (Linux): GTK4 + libadwaita front-end for `open-deck-server`.
//!
//! Locates the companion server binary, launches it, scrapes the pairing
//! token from its stdout, and polls `/status` for live stats.
//!
//! Worker threads never touch GTK widgets: they post `UiMsg`s over an
//! `std::sync::mpsc` channel that a 50ms glib timeout drains on the main loop.

use std::io::{BufRead, BufReader, Read, Write};
use std::net::TcpStream;
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use gtk4::glib;
use gtk4::prelude::*;
use libadwaita as adw;
use libadwaita::prelude::*;

// ---------------------------------------------------------------------------
// Messages posted from worker threads to the GTK main loop
// ---------------------------------------------------------------------------

#[derive(Debug)]
enum UiMsg {
    Log(String),
    /// Pairing token scraped from server stdout.
    Token(String),
    /// Monitor line scraped from server stdout ("1920x1080 @ 15fps").
    Monitor(String),
    /// Server process exited.
    Exited(i32),
    /// Server process was spawned successfully.
    Spawned,
    /// Spawn failed.
    SpawnFailed(String),
}

// ---------------------------------------------------------------------------
// Shared server state (cross-thread)
// ---------------------------------------------------------------------------

struct Shared {
    child: Mutex<Option<Child>>,
}

fn locate_server() -> Option<PathBuf> {
    let mut candidates: Vec<PathBuf> = Vec::new();

    if let Ok(p) = std::env::var("OPENSDECK_SERVER") {
        if !p.is_empty() {
            candidates.push(PathBuf::from(p));
        }
    }

    if let Ok(exe) = std::env::current_exe() {
        if let Some(dir) = exe.parent() {
            candidates.push(dir.join("open-deck-server"));
        }
    }

    if let Ok(path_env) = std::env::var("PATH") {
        for dir in path_env.split(':') {
            candidates.push(PathBuf::from(dir).join("open-deck-server"));
        }
    }

    // Repo dev builds: walk up from cwd looking for server/target/*/open-deck-server.
    if let Ok(cwd) = std::env::current_dir() {
        let mut dir = cwd.as_path();
        for _ in 0..6 {
            for profile in ["release", "debug"] {
                candidates.push(dir.join(format!("server/target/{profile}/open-deck-server")));
            }
            match dir.parent() {
                Some(p) => dir = p,
                None => break,
            }
        }
    }

    candidates.into_iter().find(|p| is_executable(p))
}

fn is_executable(path: &std::path::Path) -> bool {
    use std::os::unix::fs::PermissionsExt;
    path.is_file()
        && path
            .metadata()
            .map(|m| m.permissions().mode() & 0o111 != 0)
            .unwrap_or(false)
}

/// Minimal HTTP GET against the server's `/status` endpoint.
/// Returns the response body, or None if the server isn't reachable.
fn fetch_status(port: u16) -> Option<String> {
    let addr = format!("127.0.0.1:{port}");
    let mut stream =
        TcpStream::connect_timeout(&addr.parse().ok()?, Duration::from_millis(800)).ok()?;
    stream
        .write_all(
            format!("GET /status HTTP/1.1\r\nHost: {addr}\r\nConnection: close\r\n\r\n").as_bytes(),
        )
        .ok()?;
    let mut buf = String::new();
    stream.read_to_string(&mut buf).ok()?;
    buf.split("\r\n\r\n").nth(1).map(str::to_string)
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

/// Render a QR code as a standalone SVG string (no extra deps beyond `qrcode`).
fn render_qr_svg(payload: &str) -> Option<String> {
    let code = qrcode::QrCode::new(payload.as_bytes()).ok()?;
    Some(
        code.render::<qrcode::render::svg::Color>()
            .min_dimensions(220, 220)
            .build(),
    )
}

fn json_u64(body: &str, key: &str) -> Option<u64> {
    let pat = format!("\"{key}\":");
    let start = body.find(&pat)? + pat.len();
    let digits: String = body[start..]
        .chars()
        .take_while(|c| c.is_ascii_digit())
        .collect();
    digits.parse().ok()
}

// ---------------------------------------------------------------------------
// UI helpers
// ---------------------------------------------------------------------------

fn action_row(title: &str, subtitle: &str) -> adw::ActionRow {
    let row = adw::ActionRow::new();
    row.set_title(title);
    row.set_subtitle(subtitle);
    row
}

fn spin_row(title: &str, lo: f64, hi: f64, value: f64) -> (adw::ActionRow, gtk4::SpinButton) {
    let spin = gtk4::SpinButton::with_range(lo, hi, 1.0);
    spin.set_value(value);
    spin.set_width_request(90);
    spin.set_halign(gtk4::Align::End);
    let row = adw::ActionRow::new();
    row.set_title(title);
    row.add_suffix(&spin);
    (row, spin)
}

fn set_running_ui(running: bool, toggle: &gtk4::Button, state_row: &adw::ActionRow) {
    if running {
        toggle.set_label("Stop");
        toggle.remove_css_class("suggested-action");
        toggle.add_css_class("destructive-action");
    } else {
        toggle.set_label("Start");
        toggle.remove_css_class("destructive-action");
        toggle.add_css_class("suggested-action");
    }
    state_row.set_subtitle(if running { "Running" } else { "Stopped" });
}

fn build_ui(app: &adw::Application) -> adw::Window {
    let window = adw::Window::new();
    window.set_application(Some(app));
    window.set_title(Some("OpenDeck"));
    window.set_default_size(560, 760);

    let header = gtk4::HeaderBar::new();
    let title = adw::WindowTitle::new("OpenDeck", "Steam Deck companion");
    header.set_title_widget(Some(&title));

    let toggle = gtk4::Button::with_label("Start");
    toggle.add_css_class("suggested-action");
    header.pack_end(&toggle);
    window.set_titlebar(Some(&header));

    let shared = Arc::new(Shared {
        child: Mutex::new(None),
    });

    // ---- Status group ----
    let binary_path = locate_server();
    let binary_row = action_row(
        "Server binary",
        &binary_path
            .map(|p| p.display().to_string())
            .unwrap_or_else(|| "not found — build server/ or set OPENSDECK_SERVER".into()),
    );
    let state_row = action_row("State", "Stopped");
    let clients_row = action_row("Connected devices", "0");
    let monitor_row = action_row("Monitor", "—");

    let status_group = adw::PreferencesGroup::new();
    status_group.set_title("Status");
    for row in [&binary_row, &state_row, &clients_row, &monitor_row] {
        status_group.add(row);
    }

    // ---- Pairing group ----
    let token_row = action_row("Pairing token", "start the server to generate one");
    let copy = gtk4::Button::from_icon_name("edit-copy-symbolic");
    copy.set_tooltip_text(Some("Copy token"));
    copy.set_valign(gtk4::Align::Center);
    token_row.add_suffix(&copy);

    let qr_picture = gtk4::Picture::new();
    qr_picture.set_content_fit(gtk4::ContentFit::Contain);
    qr_picture.set_size_request(160, 160);
    qr_picture.set_valign(gtk4::Align::Center);
    qr_picture.set_visible(false);
    let qr_row = adw::ActionRow::new();
    qr_row.set_title("Scan to pair");
    qr_row.add_suffix(&qr_picture);

    let pairing_group = adw::PreferencesGroup::new();
    pairing_group.set_title("Pairing");
    pairing_group.add(&token_row);
    pairing_group.add(&qr_row);

    // ---- Settings group ----
    let (port_row, port_spin) = spin_row("Port", 1.0, 65535.0, 47821.0);
    let (fps_row, fps_spin) = spin_row("Frame rate (fps)", 1.0, 60.0, 15.0);
    let (quality_row, quality_spin) = spin_row("JPEG quality", 1.0, 100.0, 70.0);
    let (width_row, width_spin) = spin_row("Max stream width", 320.0, 7680.0, 1280.0);

    let token_entry = gtk4::Entry::new();
    token_entry.set_placeholder_text(Some("auto-generate"));
    token_entry.set_width_request(160);
    token_entry.set_halign(gtk4::Align::End);
    let custom_token_row = adw::ActionRow::new();
    custom_token_row.set_title("Pairing token (optional)");
    custom_token_row.add_suffix(&token_entry);

    let settings_group = adw::PreferencesGroup::new();
    settings_group.set_title("Server settings");
    settings_group.add(&port_row);
    settings_group.add(&fps_row);
    settings_group.add(&quality_row);
    settings_group.add(&width_row);
    settings_group.add(&custom_token_row);

    // ---- Log ----
    let log_view = gtk4::TextView::new();
    log_view.set_editable(false);
    log_view.set_monospace(true);
    log_view.set_cursor_visible(false);
    log_view.set_top_margin(8);
    log_view.set_bottom_margin(8);
    log_view.set_left_margin(8);
    log_view.set_right_margin(8);

    let scrolled = gtk4::ScrolledWindow::new();
    scrolled.set_child(Some(&log_view));
    scrolled.set_vexpand(true);
    scrolled.set_size_request(-1, 120);

    let log_frame = gtk4::Frame::new(Some("Log"));
    log_frame.set_child(Some(&scrolled));

    // ---- Layout ----
    let content = gtk4::Box::new(gtk4::Orientation::Vertical, 12);
    content.set_margin_top(16);
    content.set_margin_bottom(16);
    content.set_margin_start(16);
    content.set_margin_end(16);
    content.append(&status_group);
    content.append(&pairing_group);
    content.append(&settings_group);
    content.append(&log_frame);

    // ---- Main-loop message pump ----
    // Worker threads send UiMsg over an std mpsc channel; a short glib
    // timeout drains it on the main thread and applies widget updates.
    let (ui_tx, ui_rx) = std::sync::mpsc::channel::<UiMsg>();

    // Keep the token on the main thread for the copy button.
    let token_store = std::rc::Rc::new(std::cell::RefCell::new(String::new()));

    {
        let state_row_msg = state_row.clone();
        let token_row_msg = token_row.clone();
        let monitor_row_msg = monitor_row.clone();
        let toggle_msg = toggle.clone();
        let log_buffer = log_view.buffer();
        let shared_msg = shared.clone();
        let token_store_msg = token_store.clone();
        let port_spin_msg = port_spin.clone();
        let qr_pic_msg = qr_picture.clone();
        glib::timeout_add_local(Duration::from_millis(50), move || {
            while let Ok(msg) = ui_rx.try_recv() {
                match msg {
                    UiMsg::Log(line) => {
                        let mut end = log_buffer.end_iter();
                        log_buffer.insert(&mut end, &format!("{line}\n"));
                    }
                    UiMsg::Token(tok) => {
                        *token_store_msg.borrow_mut() = tok.clone();
                        token_row_msg.set_subtitle(&tok);
                        if let Some(ip) = lan_ip() {
                            let port = port_spin_msg.value() as u16;
                            let payload =
                                format!("opendeck://connect?host={ip}&port={port}&token={tok}");
                            if let Some(svg) = render_qr_svg(&payload) {
                                let path = std::env::temp_dir()
                                    .join(format!("opendeck-qr-{}.svg", std::process::id()));
                                if std::fs::write(&path, svg).is_ok() {
                                    if let Some(s) = path.to_str() {
                                        qr_pic_msg.set_filename(Some(s));
                                        qr_pic_msg.set_visible(true);
                                    }
                                }
                            }
                        }
                    }
                    UiMsg::Monitor(value) => {
                        monitor_row_msg.set_subtitle(&value);
                    }
                    UiMsg::Spawned => {
                        set_running_ui(true, &toggle_msg, &state_row_msg);
                    }
                    UiMsg::SpawnFailed(err) => {
                        state_row_msg.set_subtitle(&format!("error: {err}"));
                    }
                    UiMsg::Exited(code) => {
                        *shared_msg.child.lock().unwrap() = None;
                        set_running_ui(false, &toggle_msg, &state_row_msg);
                        state_row_msg.set_subtitle(&format!("Exited (status {code})"));
                    }
                }
            }
            glib::ControlFlow::Continue
        });
    }

    // ---- Status polling (every 2s, main thread, non-blocking-ish) ----
    {
        let port_spin_poll = port_spin.clone();
        let clients_row_poll = clients_row.clone();
        let monitor_row_poll = monitor_row.clone();
        glib::timeout_add_local(Duration::from_secs(2), move || {
            let port = port_spin_poll.value() as u16;
            if let Some(body) = fetch_status(port) {
                if let Some(n) = json_u64(&body, "clients") {
                    let row = clients_row_poll.clone();
                    glib::idle_add_local_once(move || {
                        row.set_subtitle(&n.to_string());
                    });
                }
                if let (Some(w), Some(h)) = (
                    json_u64(&body, "desktop_width"),
                    json_u64(&body, "desktop_height"),
                ) {
                    let row = monitor_row_poll.clone();
                    glib::idle_add_local_once(move || {
                        row.set_subtitle(&format!("{w}x{h}"));
                    });
                }
            }
            glib::ControlFlow::Continue
        });
    }

    // ---- Copy token ----
    {
        let token_store_copy = token_store.clone();
        let window_weak = window.downgrade();
        copy.connect_clicked(move |_| {
            let token = token_store_copy.borrow().clone();
            if !token.is_empty() {
                if let Some(win) = window_weak.upgrade() {
                    win.clipboard().set_text(&token);
                }
            }
        });
    }

    // ---- Start / stop ----
    {
        let shared_start = shared.clone();
        let state_row_start = state_row.clone();
        let port_s = port_spin.clone();
        let fps_s = fps_spin.clone();
        let quality_s = quality_spin.clone();
        let width_s = width_spin.clone();
        let token_e = token_entry.clone();
        let toggle_start = toggle.clone();
        let ui_tx_start = ui_tx.clone();

        toggle.connect_clicked(move |_| {
            let is_running = shared_start.child.lock().unwrap().is_some();
            if is_running {
                let child = shared_start.child.lock().unwrap().take();
                if let Some(mut child) = child {
                    let _ = child.kill();
                    let _ = child.wait();
                }
                set_running_ui(false, &toggle_start, &state_row_start);
                let _ = ui_tx_start.send(UiMsg::Log("Server stopped".to_string()));
                return;
            }

            let Some(path) = locate_server() else {
                state_row_start.set_subtitle("error: server binary not found");
                return;
            };

            let mut cmd = Command::new(&path);
            cmd.arg("--port")
                .arg(format!("{}", port_s.value() as u16))
                .arg("--fps")
                .arg(format!("{}", fps_s.value() as i32))
                .arg("--quality")
                .arg(format!("{}", quality_s.value() as i32))
                .arg("--max-width")
                .arg(format!("{}", width_s.value() as i32))
                .stdout(Stdio::piped())
                .stderr(Stdio::piped());

            let custom = token_e.text().trim().to_string();
            if !custom.is_empty() {
                cmd.arg("--token").arg(custom);
            }

            match cmd.spawn() {
                Ok(mut child) => {
                    let stdout = child.stdout.take().expect("stdout piped");
                    let stderr = child.stderr.take().expect("stderr piped");

                    *shared_start.child.lock().unwrap() = Some(child);
                    state_row_start.set_subtitle("Starting…");
                    let _ = ui_tx_start.send(UiMsg::Log(format!("Launched {}", path.display())));
                    let _ = ui_tx_start.send(UiMsg::Spawned);

                    // stdout reader: parse banner lines; detect exit via try_wait.
                    // The Child stays in `shared` so the Stop button can kill it.
                    let tx_out = ui_tx_start.clone();
                    let shared_out = shared_start.clone();
                    std::thread::spawn(move || {
                        let mut lines = BufReader::new(stdout).lines();
                        while let Ok(Some(line)) = lines.next() {
                            let line = line.trim().to_string();
                            if line.is_empty() {
                                continue;
                            }
                            if let Some(rest) = line.strip_prefix("Pairing token") {
                                if let Some(tok) = rest.split(':').nth(1) {
                                    let _ = tx_out.send(UiMsg::Token(tok.trim().to_string()));
                                }
                            } else if line.starts_with("Monitor") {
                                if let Some(idx) = line.find(':') {
                                    let _ = tx_out
                                        .send(UiMsg::Monitor(line[idx + 1..].trim().to_string()));
                                }
                            }
                            if line.contains("===")
                                || line.starts_with("Pairing token")
                                || line.starts_with("Monitor")
                                || line.starts_with("WebSocket")
                            {
                                let _ = tx_out.send(UiMsg::Log(line));
                            }
                        }

                        // stdout hit EOF → poll try_wait until the child exits.
                        // If the Stop button already took the child, just exit.
                        loop {
                            let result = {
                                let mut guard = shared_out.child.lock().unwrap();
                                match guard.as_mut() {
                                    Some(c) => c.try_wait().ok().flatten(),
                                    None => break,
                                }
                            };
                            match result {
                                Some(status) => {
                                    let code = status.code().unwrap_or(-1);
                                    let _ = tx_out.send(UiMsg::Exited(code));
                                    break;
                                }
                                None => std::thread::sleep(Duration::from_millis(100)),
                            }
                        }
                    });

                    // stderr reader (tracing logs).
                    let tx_err = ui_tx_start.clone();
                    std::thread::spawn(move || {
                        let mut lines = BufReader::new(stderr).lines();
                        while let Ok(Some(line)) = lines.next() {
                            let line = line.trim().to_string();
                            if !line.is_empty() {
                                let _ = tx_err.send(UiMsg::Log(line));
                            }
                        }
                    });
                }
                Err(e) => {
                    let _ = ui_tx_start.send(UiMsg::SpawnFailed(e.to_string()));
                }
            }
        });
    }

    window.present();
    window
}

fn main() -> glib::ExitCode {
    let app = adw::Application::builder()
        .application_id("dev.opendeck.linux")
        .build();
    app.connect_activate(|app| {
        build_ui(app);
    });
    app.run()
}
