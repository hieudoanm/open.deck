//! Host statistics broadcast to clients as `{"type":"stats",...}` messages.
//! Sampled every 2s with `sysinfo`; each connected socket forwards the latest
//! snapshot so dashboard pages can show desktop (not phone) stats.
//!
//! Battery and memory pressure come from platform probes (no extra deps):
//! - macOS: `pmset -g batt` (percent + AC/battery state) and
//!   `sysctl kern.memorystatus_level` (% memory available → pressure).
//! - Linux: `/sys/class/power_supply/*` and `/proc/pressure/memory`.

use std::collections::HashMap;
use std::time::{Duration, Instant};

use sysinfo::{Disks, Networks, System};
use tokio::sync::broadcast;

use crate::protocol::{NetInterface, ServerMessage};

const INTERVAL: Duration = Duration::from_secs(2);

/// Spawn the sampler; each receiver gets one `ServerMessage::Stats` per interval.
pub fn spawn_stats() -> broadcast::Sender<ServerMessage> {
    let (tx, _) = broadcast::channel(8);
    let out = tx.clone();
    tokio::spawn(async move {
        let Ok(mut sys) = System::new_all() else {
            tracing::warn!("sysinfo unavailable — stats broadcast disabled");
            return;
        };
        sys.refresh_cpu_all();
        sys.refresh_memory();
        sys.refresh_cpu_usage(); // prime — first real sample needs two reads

        let mut prev_net: Option<HashMap<String, (u64, u64)>> = None;
        let mut last = Instant::now();

        loop {
            tokio::time::sleep(INTERVAL).await;
            let now = Instant::now();
            let dt = now.duration_since(last).as_secs_f64().max(0.001);
            last = now;

            sys.refresh_cpu_usage();
            sys.refresh_memory();

            let disks = Disks::new_with_refreshed_list().ok();
            let disk = disks.as_ref().and_then(|ds| {
                ds.iter()
                    .find(|d| d.mount_point() == std::path::Path::new("/"))
                    .or_else(|| ds.iter().next())
            });
            let (disk_used, disk_total) = disk
                .map(|d| {
                    (
                        d.total_space().saturating_sub(d.available_space()),
                        d.total_space(),
                    )
                })
                .unwrap_or((0, 0));

            let networks = Networks::new_with_refreshed_list().ok();
            let mut totals: HashMap<String, (u64, u64)> = HashMap::new();
            if let Some(nets) = &networks {
                for (name, data) in nets {
                    totals.insert(
                        name.to_string_lossy().into_owned(),
                        (data.received(), data.transmitted()),
                    );
                }
            }
            let mut interfaces = Vec::new();
            let mut rx_total = 0u64;
            let mut tx_total = 0u64;
            for (name, (rx, tx)) in &totals {
                rx_total = rx_total.saturating_add(*rx);
                tx_total = tx_total.saturating_add(*tx);
                if let Some(prev) = prev_net.as_ref().and_then(|p| p.get(name)) {
                    interfaces.push(NetInterface {
                        name: name.clone(),
                        rx_rate: ((*rx).saturating_sub(prev.0) as f64 / dt) as u64,
                        tx_rate: ((*tx).saturating_sub(prev.1) as f64 / dt) as u64,
                    });
                }
            }
            interfaces.sort_by(|a, b| a.name.cmp(&b.name));
            prev_net = Some(totals);

            let (battery_percent, battery_state) = battery();
            let memory_pressure = memory_pressure();

            let snap = ServerMessage::Stats {
                cpu_percent: sys.global_cpu_usage(),
                mem_used: sys.used_memory(),
                mem_total: sys.total_memory(),
                swap_used: sys.used_swap(),
                swap_total: sys.total_swap(),
                disk_used,
                disk_total,
                net_rx_rate: interfaces.iter().map(|i| i.rx_rate).sum(),
                net_tx_rate: interfaces.iter().map(|i| i.tx_rate).sum(),
                net_interfaces: interfaces,
                uptime_secs: System::uptime().unwrap_or(0),
                battery_percent,
                battery_state,
                memory_pressure,
            };
            let _ = out.send(snap);
        }
    });
    tx
}

// ---------- battery ----------

/// `(percent 0-100, state)` — `None` on desktops / when unreadable.
#[cfg(target_os = "macos")]
fn battery() -> (Option<f32>, Option<String>) {
    let Ok(out) = std::process::Command::new("pmset")
        .args(["-g", "batt"])
        .output()
    else {
        return (None, None);
    };
    let text = String::from_utf8_lossy(&out.stdout);
    // "Now drawing from 'AC Power'" / "'Battery Power'"
    let on_ac = text.contains("AC Power");
    // "InternalBattery-0 (id=…)  87%; charging; …" / "discharging" / "charged"
    let mut percent = None;
    let mut state = None;
    for line in text.lines() {
        if !line.contains("Battery") && !line.contains("battery") {
            continue;
        }
        if let Some(pct) = line.split(';').next().and_then(|s| {
            s.split_whitespace()
                .find_map(|t| t.strip_suffix('%').and_then(|n| n.parse::<f32>().ok()))
        }) {
            percent = Some(pct);
        }
        for word in ["charging", "discharging", "charged", "finishing charge"] {
            if line.contains(word) {
                state = Some(
                    if word == "charged" || word == "finishing charge" {
                        "full"
                    } else {
                        word
                    }
                    .to_string(),
                );
            }
        }
    }
    if percent.is_none() {
        return (None, None);
    }
    let state = state.or_else(|| Some(if on_ac { "ac".into() } else { "battery".into() }));
    (percent, state)
}

#[cfg(target_os = "linux")]
fn battery() -> (Option<f32>, Option<String>) {
    let base = std::path::Path::new("/sys/class/power_supply");
    let Ok(entries) = std::fs::read_dir(base) else {
        return (None, None);
    };
    for entry in entries.flatten() {
        let dir = entry.path();
        let Ok(kind) = std::fs::read_to_string(dir.join("type")) else {
            continue;
        };
        if !kind.trim().eq_ignore_ascii_case("battery") {
            continue;
        }
        let percent = std::fs::read_to_string(dir.join("capacity"))
            .ok()
            .and_then(|s| s.trim().parse::<f32>().ok());
        let state = std::fs::read_to_string(dir.join("status"))
            .ok()
            .map(|s| s.trim().to_lowercase())
            .map(|s| match s.as_str() {
                "charging" => "charging",
                "discharging" => "discharging",
                "full" => "full",
                "not charging" => "full",
                _ => "unknown",
            })
            .map(str::to_string);
        return (percent, state);
    }
    (None, None)
}

#[cfg(not(any(target_os = "macos", target_os = "linux")))]
fn battery() -> (Option<f32>, Option<String>) {
    (None, None)
}

// ---------- memory pressure ----------

/// 0-100 pressure score. macOS: `kern.memorystatus_level` reports % memory
/// *available* (higher = healthier), so pressure = 100 - level. Linux:
/// `/proc/pressure/memory` `some avg10` (% of time tasks stalled on memory).
#[cfg(target_os = "macos")]
fn memory_pressure() -> Option<f32> {
    let out = std::process::Command::new("sysctl")
        .args(["-n", "kern.memorystatus_level"])
        .output()
        .ok()?;
    let level: f32 = String::from_utf8_lossy(&out.stdout).trim().parse().ok()?;
    Some((100.0 - level).clamp(0.0, 100.0))
}

#[cfg(target_os = "linux")]
fn memory_pressure() -> Option<f32> {
    let text = std::fs::read_to_string("/proc/pressure/memory").ok()?;
    // "some avg10=0.10 avg60=0.20 avg300=0.30 total=123"
    let some = text.lines().next()?;
    for field in some.split_whitespace() {
        if let Some(v) = field.strip_prefix("avg10=") {
            return v.parse::<f32>().ok();
        }
    }
    None
}

#[cfg(not(any(target_os = "macos", target_os = "linux")))]
fn memory_pressure() -> Option<f32> {
    None
}
