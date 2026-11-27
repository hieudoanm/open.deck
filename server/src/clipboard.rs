//! Host clipboard endpoints (`GET/POST/DELETE /clipboard`) so mobile clients
//! can browse and write the desktop machine's clipboard — the portable
//! analog of omni's Clipboard view / phone-local Clipboard page.
//!
//! The clipboard is polled every 2s (text only); each detected change is
//! prepended to an in-memory history (cap 100) shared with `GET /clipboard`.
//! Reads/writes shell out to platform tools: `pbpaste`/`pbcopy` (macOS),
//! `xclip`/`wl-paste`/`wl-copy` (Linux), `powershell Get-Clipboard`/`clip`
//! (Windows). All are blocking — call via `spawn_blocking` or the poll task.

use std::collections::VecDeque;
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use serde::{Deserialize, Serialize};

const MAX_ITEMS: usize = 100;
const POLL_INTERVAL: Duration = Duration::from_secs(2);

#[derive(Debug, Clone, Serialize)]
pub struct ClipboardEntry {
    pub id: u64,
    pub content: String,
    pub is_url: bool,
    pub created_at: u64,
    pub copied_count: u32,
}

#[derive(Debug)]
pub struct ClipboardState {
    items: VecDeque<ClipboardEntry>,
    next_id: u64,
    last_text: Option<String>,
}

impl ClipboardState {
    fn new() -> Self {
        Self {
            items: VecDeque::new(),
            next_id: 1,
            last_text: None,
        }
    }

    /// Record clipboard text; dedupes against the most recent entry.
    pub fn record(&mut self, text: String) {
        let text = text.trim().to_string();
        if text.is_empty() || Some(&text) == self.last_text.as_ref() {
            return;
        }
        self.last_text = Some(text.clone());
        self.push(text);
    }

    fn push(&mut self, content: String) {
        let is_url = content.starts_with("http://") || content.starts_with("https://");
        if let Some(front) = self.items.front_mut() {
            if front.content == content {
                front.copied_count += 1;
                return;
            }
        }
        let entry = ClipboardEntry {
            id: self.next_id,
            content,
            is_url,
            created_at: now_unix(),
            copied_count: 1,
        };
        self.next_id += 1;
        self.items.push_front(entry);
        while self.items.len() > MAX_ITEMS {
            self.items.pop_back();
        }
    }

    pub fn snapshot(&self) -> Vec<ClipboardEntry> {
        self.items.iter().cloned().collect()
    }

    pub fn clear(&mut self) {
        self.items.clear();
    }
}

pub type SharedClipboard = Arc<Mutex<ClipboardState>>;

pub fn new_state() -> SharedClipboard {
    Arc::new(Mutex::new(ClipboardState::new()))
}

/// Spawn the 2s clipboard poller; detected changes land in `state`.
pub fn spawn_poller(state: SharedClipboard) {
    tokio::spawn(async move {
        loop {
            tokio::time::sleep(POLL_INTERVAL).await;
            let text = tokio::task::spawn_blocking(read_clipboard_text)
                .await
                .unwrap_or_default();
            if let Ok(mut guard) = state.lock() {
                if let Some(t) = text {
                    guard.record(t);
                }
            }
        }
    });
}

fn now_unix() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

// ---------- platform clipboard ----------

/// Read clipboard text; `None` when unavailable or non-text.
#[cfg(target_os = "macos")]
fn read_clipboard_text() -> Option<String> {
    let out = std::process::Command::new("pbpaste").output().ok()?;
    if !out.status.success() {
        return None;
    }
    Some(String::from_utf8_lossy(&out.stdout).into_owned())
}

#[cfg(target_os = "macos")]
fn write_clipboard_text(text: &str) -> Result<(), String> {
    use std::io::Write;
    let mut child = std::process::Command::new("pbcopy")
        .stdin(std::process::Stdio::piped())
        .spawn()
        .map_err(|e| e.to_string())?;
    child
        .stdin
        .as_mut()
        .unwrap()
        .write_all(text.as_bytes())
        .map_err(|e| e.to_string())?;
    child.wait().map_err(|e| e.to_string())?;
    Ok(())
}

#[cfg(target_os = "linux")]
fn read_clipboard_text() -> Option<String> {
    // X11 first, then Wayland compositors.
    for cmd in [
        vec!["xclip", "-selection", "clipboard", "-o"],
        vec!["wl-paste", "-n"],
    ] {
        if let Ok(out) = std::process::Command::new(cmd[0]).args(&cmd[1..]).output() {
            if out.status.success() {
                return Some(String::from_utf8_lossy(&out.stdout).into_owned());
            }
        }
    }
    None
}

#[cfg(target_os = "linux")]
fn write_clipboard_text(text: &str) -> Result<(), String> {
    use std::io::Write;
    for cmd in [vec!["xclip", "-selection", "clipboard"], vec!["wl-copy"]] {
        let Ok(mut child) = std::process::Command::new(cmd[0])
            .args(&cmd[1..])
            .stdin(std::process::Stdio::piped())
            .spawn()
        else {
            continue;
        };
        if child
            .stdin
            .as_mut()
            .unwrap()
            .write_all(text.as_bytes())
            .is_ok()
            && child.wait().map(|s| s.success()).unwrap_or(false)
        {
            return Ok(());
        }
    }
    Err("no clipboard tool available (install xclip or wl-clipboard)".into())
}

#[cfg(windows)]
fn read_clipboard_text() -> Option<String> {
    let out = std::process::Command::new("powershell")
        .args(["-NoProfile", "-Command", "Get-Clipboard"])
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    Some(String::from_utf8_lossy(&out.stdout).into_owned())
}

#[cfg(windows)]
fn write_clipboard_text(text: &str) -> Result<(), String> {
    use std::io::Write;
    let mut child = std::process::Command::new("clip")
        .stdin(std::process::Stdio::piped())
        .spawn()
        .map_err(|e| e.to_string())?;
    child
        .stdin
        .as_mut()
        .unwrap()
        .write_all(text.as_bytes())
        .map_err(|e| e.to_string())?;
    child.wait().map_err(|e| e.to_string())?;
    Ok(())
}

#[cfg(not(any(target_os = "macos", target_os = "linux", windows)))]
fn read_clipboard_text() -> Option<String> {
    None
}

#[cfg(not(any(target_os = "macos", target_os = "linux", windows)))]
fn write_clipboard_text(_text: &str) -> Result<(), String> {
    Err("clipboard unsupported on this platform".into())
}

// ---------- request/response ----------

#[derive(Debug, Deserialize)]
pub struct ClipboardWrite {
    pub content: String,
}

/// `spawn_blocking` target for `POST /clipboard`.
pub fn write_clipboard_text_pub(text: &str) -> Result<(), String> {
    write_clipboard_text(text)
}
