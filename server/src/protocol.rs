//! Wire protocol shared between open-deck-server and the mobile clients.
//! See docs/PROTOCOL.md for the human-readable spec.

use serde::{Deserialize, Serialize};

/// Info sent as the first text frame after the WebSocket upgrade.
#[allow(dead_code)] // `Error` is part of the protocol surface for future use
#[derive(Debug, Clone, Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ServerMessage {
    Hello {
        version: u32,
        name: String,
        /// Native resolution of the captured monitor.
        desktop_width: u32,
        desktop_height: u32,
        /// Resolution of the JPEG frames actually streamed.
        stream_width: u32,
        stream_height: u32,
        fps: u32,
        max_fps: u32,
    },
    Pong,
    /// Periodic host stats (~2s cadence), so clients can show desktop metrics.
    Stats {
        cpu_percent: f32,
        mem_used: u64,
        mem_total: u64,
        swap_used: u64,
        swap_total: u64,
        disk_used: u64,
        disk_total: u64,
        /// Bytes/sec, computed server-side from counter deltas.
        net_rx_rate: u64,
        net_tx_rate: u64,
        /// Per-interface byte rates (loopback included; clients filter).
        #[serde(default, skip_serializing_if = "Vec::is_empty")]
        net_interfaces: Vec<NetInterface>,
        uptime_secs: u64,
        #[serde(skip_serializing_if = "Option::is_none")]
        battery_percent: Option<f32>,
        /// "charging" | "discharging" | "full" | "ac" | "battery" | "unknown"
        #[serde(skip_serializing_if = "Option::is_none")]
        battery_state: Option<String>,
        /// Memory pressure 0-100 (higher = more pressure). macOS:
        /// 100 - kern.memorystatus_level; Linux: /proc/pressure/memory avg10.
        #[serde(skip_serializing_if = "Option::is_none")]
        memory_pressure: Option<f32>,
    },
    Error {
        message: String,
    },
}

/// Per-network-interface throughput sample inside `Stats`.
#[derive(Debug, Clone, Serialize)]
pub struct NetInterface {
    pub name: String,
    pub rx_rate: u64,
    pub tx_rate: u64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MouseButton {
    Left,
    Right,
    Middle,
    Back,
    Forward,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ButtonState {
    Down,
    Up,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KeyState {
    Down,
    Up,
    Press,
}

/// One text frame from a client.
#[allow(dead_code)] // `version` is reserved for future protocol negotiation
#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ClientMessage {
    Hello {
        name: Option<String>,
        version: Option<u32>,
    },
    /// Absolute desktop pixel coordinates.
    MouseMove {
        x: i32,
        y: i32,
    },
    MouseButton {
        button: MouseButton,
        state: ButtonState,
    },
    /// Scroll ticks. Positive `dy` scrolls down, positive `dx` scrolls right.
    Scroll {
        dx: i32,
        dy: i32,
    },
    /// `key` is a single char, a key name ("Return", "F5", "ArrowUp", ...),
    /// or a chord like "Control+S" (only meaningful with state "press").
    Key {
        key: String,
        state: KeyState,
    },
    /// Type a literal string via the OS text-input path.
    Text {
        text: String,
    },
    /// Trigger a named server-side action (see `GET /actions`).
    RunAction {
        name: String,
    },
    Ping,
}

/// A single encoded screen frame shared with all connected clients.
#[derive(Debug, Clone)]
pub struct Frame {
    pub jpeg: std::sync::Arc<Vec<u8>>,
    pub width: u32,
    pub height: u32,
}
