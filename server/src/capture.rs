//! Screen capture loop: grabs the primary monitor with xcap, downscales and
//! JPEG-encodes it, and broadcasts frames to all connected WebSocket clients.

use std::sync::Arc;
use std::time::Duration;

use anyhow::{Context, Result};
use image::codecs::jpeg::JpegEncoder;
use tokio::sync::broadcast;
use tracing::{info, warn};
use xcap::Monitor;

use crate::protocol::Frame;

pub struct CaptureConfig {
    pub fps: u32,
    pub quality: u8,
    pub max_width: u32,
    pub max_height: u32,
}

/// Native size of the captured monitor.
#[derive(Debug, Clone, Copy)]
pub struct MonitorInfo {
    pub width: u32,
    pub height: u32,
}

/// Returns the broadcast sender plus the monitor's native resolution.
/// Spawns the capture task on the current tokio runtime.
pub fn spawn_capture(cfg: CaptureConfig) -> Result<(broadcast::Sender<Arc<Frame>>, MonitorInfo)> {
    let monitors = Monitor::all().context("enumerate monitors")?;
    let monitor = monitors
        .into_iter()
        .find(|m| m.is_primary().unwrap_or(false))
        .or_else(|| Monitor::all().ok()?.into_iter().next())
        .context("no monitor found")?;

    let info = MonitorInfo {
        width: monitor.width().unwrap_or(0),
        height: monitor.height().unwrap_or(0),
    };
    info!(?info, "capturing primary monitor");

    let (tx, _) = broadcast::channel::<Arc<Frame>>(4);
    let tx2 = tx.clone();

    tokio::task::spawn_blocking(move || {
        let interval = Duration::from_secs_f64(1.0 / cfg.fps.max(1) as f64);
        loop {
            let start = std::time::Instant::now();
            if tx2.receiver_count() > 0 {
                match capture_frame(&monitor, &cfg) {
                    Ok(Some(f)) => {
                        let _ = tx2.send(Arc::new(f));
                    }
                    Ok(None) => {}
                    Err(e) => warn!("capture failed: {e:#}"),
                }
            }
            let elapsed = start.elapsed();
            if elapsed < interval {
                std::thread::sleep(interval - elapsed);
            }
        }
    });

    Ok((tx, info))
}

fn capture_frame(monitor: &Monitor, cfg: &CaptureConfig) -> Result<Option<Frame>> {
    let rgba = monitor.capture_image().context("capture_image")?;
    let thumb = image::imageops::thumbnail(&rgba, cfg.max_width.max(2), cfg.max_height.max(2));
    let (width, height) = (thumb.width(), thumb.height());
    let mut jpeg = Vec::with_capacity(thumb.width() as usize * thumb.height() as usize / 4);
    let mut enc = JpegEncoder::new_with_quality(&mut jpeg, cfg.quality);
    enc.encode_image(&image::DynamicImage::ImageRgba8(thumb))
        .context("jpeg encode")?;
    Ok(Some(Frame {
        jpeg: Arc::new(jpeg),
        width,
        height,
    }))
}
