//! Host introspection endpoints (`GET /ports`, `GET /apps`) so mobile clients
//! can show the desktop machine's listening ports and running processes —
//! the portable analogs of omni's Ports and Apps views.
//!
//! Port discovery shells out to `lsof` on unix and `netstat` on Windows;
//! process listing uses `sysinfo`. Both are blocking, so handlers must call
//! these via `tokio::task::spawn_blocking`.

use serde::Serialize;
use sysinfo::{Pid, ProcessesToUpdate, System};

#[derive(Debug, Serialize)]
pub struct PortEntry {
    pub protocol: String, // "tcp" | "udp"
    pub address: String,  // local bind address, e.g. "127.0.0.1" or "*"
    pub port: u16,
    pub state: String, // "listening" | "open" (udp) | "other"
    pub pid: u32,
    pub process: String,
}

#[derive(Debug, Serialize)]
pub struct AppEntry {
    pub pid: u32,
    pub name: String,
    pub cpu_percent: f32,
    pub mem_bytes: u64,
}

/// All TCP listeners + bound UDP sockets, sorted by port.
pub fn list_ports() -> Vec<PortEntry> {
    #[cfg(windows)]
    {
        let mut ports = parse_netstat();
        fill_process_names(&mut ports);
        ports.sort_by_key(|p| (p.protocol.clone(), p.port));
        ports
    }
    #[cfg(not(windows))]
    {
        let mut ports = parse_lsof();
        fill_process_names(&mut ports);
        ports.sort_by_key(|p| (p.protocol.clone(), p.port));
        ports
    }
}

/// Running processes with cpu/mem, sorted by memory descending.
pub fn list_apps() -> Vec<AppEntry> {
    let Ok(mut sys) = System::new_all() else {
        return Vec::new();
    };
    sys.refresh_processes(ProcessesToUpdate::All, true);
    let mut apps: Vec<AppEntry> = sys
        .processes()
        .values()
        .map(|p| AppEntry {
            pid: p.pid().as_u32(),
            name: p.name().to_string_lossy().into_owned(),
            cpu_percent: p.cpu_usage(),
            mem_bytes: p.memory(),
        })
        .collect();
    apps.sort_by(|a, b| b.mem_bytes.cmp(&a.mem_bytes).then(a.name.cmp(&b.name)));
    apps
}

// ---------- unix: lsof ----------

#[cfg(not(windows))]
fn parse_lsof() -> Vec<PortEntry> {
    let mut ports = Vec::new();
    for (args, proto) in [
        (vec!["-nP", "-iTCP", "-sTCP:LISTEN"], "tcp"),
        (vec!["-nP", "-iUDP"], "udp"),
    ] {
        let Ok(out) = std::process::Command::new("lsof").args(&args).output() else {
            continue;
        };
        let text = String::from_utf8_lossy(&out.stdout);
        for line in text.lines().skip(1) {
            // COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME [(LISTEN)]
            let mut cols = line.split_whitespace();
            let (Some(command), Some(pid_s)) = (cols.next(), cols.next()) else {
                continue;
            };
            // Find the NAME field: first token shaped like `host:port`.
            // TCP listeners append `(LISTEN)` after it; UDP connected
            // sockets look like `local->remote`.
            let Some((address, port)) = cols.find_map(parse_endpoint) else {
                continue;
            };
            let pid: u32 = pid_s.parse().unwrap_or(0);
            let state = if proto == "tcp" { "listening" } else { "open" };
            ports.push(PortEntry {
                protocol: proto.into(),
                address,
                port,
                state: state.into(),
                pid,
                process: command.replace("\\x20", " "),
            });
        }
    }
    ports
}

/// Parse an lsof NAME token into (address, port). Handles `*:3000`,
/// `127.0.0.1:8080`, `[::1]:443`, `host:53->peer:53`; returns None for
/// unbound (`*:*`) or non-endpoint tokens like `(LISTEN)`.
#[cfg(not(windows))]
fn parse_endpoint(token: &str) -> Option<(String, u16)> {
    let local = token.split("->").next()?;
    let (host, port_s) = local.rsplit_once(':')?;
    let port: u16 = port_s.parse().ok()?;
    let host = host.trim_start_matches('[').trim_end_matches(']');
    if host.is_empty() || host == "*" {
        return Some(("*".into(), port));
    }
    Some((host.into(), port))
}

// ---------- windows: netstat ----------

#[cfg(windows)]
fn parse_netstat() -> Vec<PortEntry> {
    let mut ports = Vec::new();
    for proto in ["tcp", "udp"] {
        let Ok(out) = std::process::Command::new("netstat")
            .args(["-ano", "-p", proto])
            .output()
        else {
            continue;
        };
        let text = String::from_utf8_lossy(&out.stdout);
        for line in text.lines() {
            let cols: Vec<&str> = line.split_whitespace().collect();
            // "TCP"/"UDP"  local-addr  foreign-addr  [state]  pid
            if cols.len() < 4 || !cols[0].eq_ignore_ascii_case(proto) {
                continue;
            }
            let local = cols[1];
            let Some((address, port_s)) = local.rsplit_once(':') else {
                continue;
            };
            let Ok(port) = port_s.parse::<u16>() else {
                continue;
            };
            let pid: u32 = cols.last().and_then(|s| s.parse().ok()).unwrap_or(0);
            let state = if proto == "tcp" {
                if cols.get(3).copied() == Some("LISTENING") {
                    "listening"
                } else {
                    "other"
                }
            } else {
                "open"
            };
            // For tcp, only keep listeners (matches omni's Ports view).
            if proto == "tcp" && state != "listening" {
                continue;
            }
            ports.push(PortEntry {
                protocol: proto.into(),
                address: address.into(),
                port,
                state: state.into(),
                pid,
                process: String::new(),
            });
        }
    }
    ports
}

/// Best-effort pid → process-name lookup via sysinfo for entries whose
/// collector didn't already provide a name (Windows netstat path).
fn fill_process_names(ports: &mut [PortEntry]) {
    let needs_lookup = ports.iter().any(|p| p.process.is_empty() && p.pid > 0);
    if !needs_lookup {
        return;
    }
    let Ok(mut sys) = System::new_all() else {
        return;
    };
    sys.refresh_processes(ProcessesToUpdate::All, true);
    for p in ports.iter_mut() {
        if p.process.is_empty() {
            if let Some(proc) = sys.process(Pid::from_u32(p.pid)) {
                p.process = proc.name().to_string_lossy().into_owned();
            }
        }
    }
}
