//! Host statistics broadcast to clients as `{"type":"stats",...}` messages.
//! Sampled every 2s with `sysinfo`; each connected socket forwards the latest
//! snapshot so dashboard pages can show desktop (not phone) stats.

use std::time::{Duration, Instant};

use sysinfo::{Disks, Networks, System};
use tokio::sync::broadcast;

use crate::protocol::ServerMessage;

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

        let mut prev_net: Option<(u64, u64)> = None;
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
            let mut rx_total = 0u64;
            let mut tx_total = 0u64;
            if let Some(nets) = &networks {
                for (_, data) in nets {
                    rx_total = rx_total.saturating_add(data.received());
                    tx_total = tx_total.saturating_add(data.transmitted());
                }
            }
            let (net_rx_rate, net_tx_rate) = match prev_net {
                Some((prx, ptx)) => (
                    ((rx_total.saturating_sub(prx)) as f64 / dt) as u64,
                    ((tx_total.saturating_sub(ptx)) as f64 / dt) as u64,
                ),
                None => (0, 0),
            };
            prev_net = Some((rx_total, tx_total));

            let snap = ServerMessage::Stats {
                cpu_percent: sys.global_cpu_usage(),
                mem_used: sys.used_memory(),
                mem_total: sys.total_memory(),
                swap_used: sys.used_swap(),
                swap_total: sys.total_swap(),
                disk_used,
                disk_total,
                net_rx_rate,
                net_tx_rate,
                uptime_secs: System::uptime().unwrap_or(0),
                battery_percent: None,
            };
            let _ = out.send(snap);
        }
    });
    tx
}
