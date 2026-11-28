//! Host controls for the web Control page: Wi-Fi, sound mute, Bluetooth,
//! keyboard layout cycling, and display brightness.
//!
//! Each control reports `{id,label,kind,supported,...}`; `kind` is
//! `toggle` (on/off), `cycle` (keyboard layouts), or `level` (0-100
//! brightness). Unsupported controls still appear so the UI can explain
//! why (e.g. missing tool / no swift toolchain).

use serde::Serialize;
use std::process::Command;

#[derive(Serialize, Clone)]
pub struct ControlInfo {
    pub id: String,
    pub label: String,
    pub kind: String,
    pub supported: bool,
    /// Toggle state for `toggle` controls.
    pub on: Option<bool>,
    /// 0-100 level for `level` controls.
    pub value: Option<i64>,
    /// Extra state: layout name, device name, or unavailable reason.
    pub detail: Option<String>,
}

impl ControlInfo {
    fn toggle(id: &str, label: &str, on: Option<bool>, detail: Option<String>) -> Self {
        Self {
            id: id.into(),
            label: label.into(),
            kind: "toggle".into(),
            supported: on.is_some(),
            on,
            value: None,
            detail,
        }
    }

    fn unsupported(id: &str, label: &str, kind: &str, reason: &str) -> Self {
        Self {
            id: id.into(),
            label: label.into(),
            kind: kind.into(),
            supported: false,
            on: None,
            value: None,
            detail: Some(reason.into()),
        }
    }
}

fn sh(program: &str, args: &[&str]) -> Result<String, String> {
    let out = Command::new(program)
        .args(args)
        .output()
        .map_err(|e| format!("{program}: {e}"))?;
    if !out.status.success() {
        return Err(format!(
            "{program} exited {}",
            out.status.code().unwrap_or(-1)
        ));
    }
    Ok(String::from_utf8_lossy(&out.stdout).trim().to_string())
}

/// Act on a control. `action` is "toggle", "next" (cycle), or "set"
/// (level, with `value` 0-100).
pub fn act(id: &str, action: &str, value: Option<i64>) -> Result<(), String> {
    act_impl(id, action, value)
}

#[cfg(target_os = "macos")]
pub fn list_controls() -> Vec<ControlInfo> {
    vec![
        ControlInfo::toggle("wifi", "Wi-Fi", wifi_state(), wifi_detail()),
        sound_control(),
        bluetooth_control(),
        keyboard_control(),
        brightness_control(),
    ]
}

#[cfg(target_os = "linux")]
pub fn list_controls() -> Vec<ControlInfo> {
    vec![
        ControlInfo::toggle("wifi", "Wi-Fi", wifi_state(), None),
        sound_control(),
        bluetooth_control(),
        ControlInfo::unsupported(
            "keyboard",
            "Keyboard",
            "cycle",
            "not supported on linux yet",
        ),
        brightness_control(),
    ]
}

#[cfg(target_os = "windows")]
pub fn list_controls() -> Vec<ControlInfo> {
    ["wifi", "sound", "bluetooth", "keyboard", "brightness"]
        .iter()
        .map(|id| ControlInfo::unsupported(id, id, "toggle", "not supported on windows yet"))
        .collect()
}

// ================= macOS =================

#[cfg(target_os = "macos")]
fn wifi_device() -> Option<String> {
    let out = sh("networksetup", &["-listallhardwareports"]).ok()?;
    let mut lines = out.lines();
    while let Some(line) = lines.next() {
        if line.trim() == "Hardware Port: Wi-Fi" {
            for l in lines.by_ref() {
                let t = l.trim();
                if let Some(rest) = t.strip_prefix("Device:") {
                    return Some(rest.trim().to_string());
                }
                if t.starts_with("Hardware Port:") {
                    break;
                }
            }
        }
    }
    None
}

#[cfg(target_os = "macos")]
fn wifi_state() -> Option<bool> {
    let dev = wifi_device()?;
    let out = sh("networksetup", &["-getairportpower", &dev]).ok()?;
    if out.ends_with("On") {
        Some(true)
    } else if out.ends_with("Off") {
        Some(false)
    } else {
        None
    }
}

#[cfg(target_os = "macos")]
fn wifi_detail() -> Option<String> {
    wifi_device()
}

#[cfg(target_os = "macos")]
fn wifi_set(on: bool) -> Result<(), String> {
    let dev = wifi_device().ok_or("no Wi-Fi hardware port")?;
    sh(
        "networksetup",
        &["-setairportpower", &dev, if on { "on" } else { "off" }],
    )?;
    Ok(())
}

#[cfg(target_os = "macos")]
fn sound_state() -> Option<bool> {
    match sh(
        "osascript",
        &["-e", "output muted of (get volume settings)"],
    )
    .ok()?
    .as_str()
    {
        "true" => Some(false),
        "false" => Some(true),
        _ => None,
    }
}

#[cfg(target_os = "macos")]
fn sound_muted() -> Option<bool> {
    sound_state().map(|on| !on)
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
fn sound_control() -> ControlInfo {
    let volume = sound_volume();
    ControlInfo {
        id: "sound".into(),
        label: "Sound".into(),
        kind: "level".into(),
        supported: volume.is_some(),
        on: sound_state(),
        value: volume,
        detail: if volume.is_some() && sound_muted() == Some(true) {
            Some("muted".into())
        } else {
            None
        },
    }
}

#[cfg(target_os = "macos")]
fn sound_volume() -> Option<i64> {
    sh(
        "osascript",
        &["-e", "output volume of (get volume settings)"],
    )
    .ok()?
    .parse::<i64>()
    .ok()
}

#[cfg(target_os = "macos")]
fn sound_set_volume(v: i64) -> Result<(), String> {
    sh(
        "osascript",
        &[
            "-e",
            &format!("set volume output volume {v}"),
            "-e",
            "set volume output muted false",
        ],
    )?;
    Ok(())
}

#[cfg(target_os = "macos")]
fn sound_set(muted: bool) -> Result<(), String> {
    sh(
        "osascript",
        &[
            "-e",
            &format!(
                "set volume output muted {}",
                if muted { "true" } else { "false" }
            ),
        ],
    )?;
    Ok(())
}

// ---- macOS helpers needing a compiled Swift binary (TIS / DisplayServices /
// IOBluetooth private APIs) ----

#[cfg(target_os = "macos")]
fn ctl_bin() -> Result<std::path::PathBuf, String> {
    use std::sync::OnceLock;
    static CACHE: OnceLock<Result<std::path::PathBuf, String>> = OnceLock::new();
    CACHE
        .get_or_init(|| {
            let dir = std::env::temp_dir().join("opendeck-ctl");
            let bin = dir.join("opendeck-ctl");
            if bin.exists() {
                return Ok(bin);
            }
            let swiftc = sh("xcrun", &["--find", "swiftc"]).or_else(|_| {
                Command::new("which")
                    .arg("swiftc")
                    .output()
                    .ok()
                    .and_then(|o| {
                        let p = String::from_utf8_lossy(&o.stdout).trim().to_string();
                        if p.is_empty() {
                            None
                        } else {
                            Some(p)
                        }
                    })
                    .ok_or_else(|| "swiftc not found".to_string())
            })?;
            std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
            // swiftc only allows top-level code in a file named main.swift.
            let src = dir.join("main.swift");
            std::fs::write(&src, include_str!("opendeck-ctl.swift")).map_err(|e| e.to_string())?;
            let out = Command::new(swiftc)
                .args(["-O", "-o"])
                .arg(&bin)
                .arg(&src)
                .output()
                .map_err(|e| format!("swiftc: {e}"))?;
            if !out.status.success() {
                return Err(format!(
                    "swiftc compile failed: {}",
                    String::from_utf8_lossy(&out.stderr).trim()
                ));
            }
            Ok(bin)
        })
        .clone()
}

#[cfg(target_os = "macos")]
fn ctl(args: &[&str]) -> Result<String, String> {
    let bin = ctl_bin()?;
    let out = Command::new(&bin)
        .args(args)
        .output()
        .map_err(|e| e.to_string())?;
    let stdout = String::from_utf8_lossy(&out.stdout).trim().to_string();
    if !out.status.success() {
        return Err(format!(
            "ctl {} failed: {}",
            args.join(" "),
            String::from_utf8_lossy(&out.stderr).trim()
        ));
    }
    Ok(stdout)
}

#[cfg(target_os = "macos")]
fn bluetooth_control() -> ControlInfo {
    match ctl(&["bt", "get"]) {
        Ok(v) => match v.as_str() {
            "on" | "off" => ControlInfo::toggle("bluetooth", "Bluetooth", Some(v == "on"), None),
            _ => ControlInfo::unsupported(
                "bluetooth",
                "Bluetooth",
                "toggle",
                &format!("helper: {v}"),
            ),
        },
        Err(e) => ControlInfo::unsupported("bluetooth", "Bluetooth", "toggle", &e),
    }
}

#[cfg(target_os = "macos")]
fn bt_set(on: bool) -> Result<(), String> {
    ctl(&["bt", "set", if on { "1" } else { "0" }])?;
    Ok(())
}

#[cfg(target_os = "macos")]
fn keyboard_control() -> ControlInfo {
    #[derive(serde::Deserialize)]
    struct Kbd {
        name: String,
        #[serde(default)]
        current: bool,
    }
    let supported = ctl_bin().is_ok();
    let detail = ctl(&["kbd", "list"])
        .ok()
        .and_then(|out| serde_json::from_str::<Vec<Kbd>>(&out).ok())
        .and_then(|rows| {
            rows.iter()
                .find(|k| k.current)
                .or_else(|| rows.first())
                .map(|k| k.name.clone())
        })
        .or_else(|| (!supported).then(|| "needs Xcode CLT (swiftc)".to_string()));
    ControlInfo {
        id: "keyboard".into(),
        label: "Keyboard".into(),
        kind: "cycle".into(),
        supported,
        on: None,
        value: None,
        detail,
    }
}

#[cfg(target_os = "macos")]
fn kbd_next() -> Result<(), String> {
    ctl(&["kbd", "next"])?;
    Ok(())
}

#[cfg(target_os = "macos")]
fn brightness_control() -> ControlInfo {
    match ctl(&["bri", "get"]) {
        Ok(v) => match v.parse::<i64>() {
            Ok(pct) => ControlInfo {
                id: "brightness".into(),
                label: "Brightness".into(),
                kind: "level".into(),
                supported: true,
                on: None,
                value: Some(pct.clamp(0, 100)),
                detail: None,
            },
            Err(_) => ControlInfo::unsupported(
                "brightness",
                "Brightness",
                "level",
                &format!("helper: {v}"),
            ),
        },
        Err(e) => ControlInfo::unsupported("brightness", "Brightness", "level", &e),
    }
}

#[cfg(target_os = "macos")]
fn bri_set(v: i32) -> Result<(), String> {
    ctl(&["bri", "set", &v.to_string()])?;
    Ok(())
}

#[cfg(target_os = "macos")]
fn act_impl(id: &str, action: &str, value: Option<i64>) -> Result<(), String> {
    match id {
        "wifi" => wifi_set(!wifi_state().unwrap_or(false)),
        "sound" if action == "set" => {
            let v = value.ok_or("sound needs a value")?;
            sound_set_volume(v.clamp(0, 100))
        }
        "sound" => sound_set(!sound_muted().unwrap_or(false)),
        "bluetooth" => {
            let cur = ctl(&["bt", "get"])?;
            bt_set(!cur.eq_ignore_ascii_case("on"))
        }
        "keyboard" if action == "next" => kbd_next(),
        "brightness" if action == "set" => {
            let v = value.ok_or("brightness needs a value")?;
            bri_set(v.clamp(0, 100) as i32)
        }
        _ => Err(format!("unknown control '{id}' or bad action")),
    }
}

// ================= Linux =================

#[cfg(target_os = "linux")]
fn wifi_state() -> Option<bool> {
    match sh("nmcli", &["radio", "wifi"]).ok()?.as_str() {
        "enabled" => Some(true),
        "disabled" => Some(false),
        _ => None,
    }
}

#[cfg(target_os = "linux")]
fn wifi_set(on: bool) -> Result<(), String> {
    sh("nmcli", &["radio", "wifi", if on { "on" } else { "off" }])?;
    Ok(())
}

#[cfg(target_os = "linux")]
fn sound_state() -> Option<bool> {
    let out = sh("pactl", &["get-sink-mute", "@DEFAULT_SINK@"]).ok()?;
    // "Mute: yes" / "Mute: no"
    if out.ends_with("yes") {
        Some(false)
    } else if out.ends_with("no") {
        Some(true)
    } else {
        None
    }
}

#[cfg(target_os = "linux")]
fn sound_muted() -> Option<bool> {
    sound_state().map(|on| !on)
}

#[cfg(target_os = "linux")]
fn sound_volume() -> Option<i64> {
    // "Volume: front-left: X /  65% /  ..." — take the first percentage.
    let out = sh("pactl", &["get-sink-volume", "@DEFAULT_SINK@"]).ok()?;
    out.split('%')
        .next()
        .and_then(|head| head.rsplit('/').next())
        .and_then(|n| n.trim().parse::<i64>().ok())
}

#[cfg(target_os = "linux")]
fn sound_set_volume(v: i64) -> Result<(), String> {
    sh(
        "pactl",
        &["set-sink-volume", "@DEFAULT_SINK@", &format!("{v}%")],
    )?;
    let _ = sh("pactl", &["set-sink-mute", "@DEFAULT_SINK@", "unmute"]);
    Ok(())
}

#[cfg(target_os = "linux")]
fn sound_set(muted: bool) -> Result<(), String> {
    sh(
        "pactl",
        &[
            "set-sink-mute",
            "@DEFAULT_SINK@",
            if muted { "mute" } else { "unmute" },
        ],
    )?;
    Ok(())
}

#[cfg(target_os = "linux")]
fn bluetooth_control() -> ControlInfo {
    match bt_state_str() {
        Ok(v) => ControlInfo::toggle("bluetooth", "Bluetooth", Some(v == "on"), None),
        Err(e) => ControlInfo::unsupported("bluetooth", "Bluetooth", "toggle", &e),
    }
}

#[cfg(target_os = "linux")]
fn bt_state_str() -> Result<String, String> {
    let out = sh("bluetoothctl", &["show"])?;
    out.lines()
        .find_map(|l| l.trim().strip_prefix("Powered:"))
        .map(|v| {
            if v.trim() == "yes" {
                "on".to_string()
            } else {
                "off".to_string()
            }
        })
        .ok_or_else(|| "no Powered field".to_string())
}

#[cfg(target_os = "linux")]
fn bt_set(on: bool) -> Result<(), String> {
    sh("bluetoothctl", &["power", if on { "on" } else { "off" }])?;
    Ok(())
}

#[cfg(target_os = "linux")]
fn kbd_next() -> Result<(), String> {
    Err("keyboard control not supported on linux".into())
}

#[cfg(target_os = "linux")]
fn brightness_control() -> ControlInfo {
    // brightnessctl: "device,percent" per line; use the first device.
    if let Ok(out) = sh("brightnessctl", &["-m"]) {
        if let Some(line) = out.lines().next() {
            if let Some((_, pct)) = line.rsplit_once(',') {
                if let Ok(v) = pct.trim().parse::<i64>() {
                    return ControlInfo {
                        id: "brightness".into(),
                        label: "Brightness".into(),
                        kind: "level".into(),
                        supported: true,
                        on: None,
                        value: Some(v.clamp(0, 100)),
                        detail: None,
                    };
                }
            }
        }
    }
    // xrandr fallback: brightest "Brightness:" value across outputs.
    if let Ok(out) = sh("xrandr", &["--verbose", "--current"]) {
        let mut best: Option<f64> = None;
        for line in out.lines() {
            if let Some(rest) = line.trim().strip_prefix("Brightness:") {
                if let Ok(v) = rest.trim().parse::<f64>() {
                    best = Some(best.map_or(v, |b| b.max(v)));
                }
            }
        }
        if let Some(v) = best {
            return ControlInfo {
                id: "brightness".into(),
                label: "Brightness".into(),
                kind: "level".into(),
                supported: true,
                on: None,
                value: Some((v * 100.0).round() as i64),
                detail: Some("xrandr".into()),
            };
        }
    }
    ControlInfo::unsupported(
        "brightness",
        "Brightness",
        "level",
        "no brightnessctl/xrandr",
    )
}

#[cfg(target_os = "linux")]
fn bri_set(v: i32) -> Result<(), String> {
    if Command::new("brightnessctl")
        .args(["set", &format!("{v}%")])
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
    {
        return Ok(());
    }
    // xrandr fallback: apply to every connected output.
    let outputs = sh("xrandr", &["--query"])?;
    let mut any = false;
    for line in outputs.lines() {
        let mut it = line.split_whitespace();
        let name = it.next().unwrap_or("");
        if it.any(|t| t == "connected") && !name.is_empty() {
            let frac = v as f64 / 100.0;
            let _ = Command::new("xrandr")
                .args(["--output", name, "--brightness", &format!("{frac:.2}")])
                .status();
            any = true;
        }
    }
    if any {
        Ok(())
    } else {
        Err("no brightness backend".into())
    }
}

#[cfg(target_os = "linux")]
fn act_impl(id: &str, action: &str, value: Option<i64>) -> Result<(), String> {
    match id {
        "wifi" => wifi_set(!wifi_state().unwrap_or(false)),
        "sound" if action == "set" => {
            let v = value.ok_or("sound needs a value")?;
            sound_set_volume(v.clamp(0, 100))
        }
        "sound" => sound_set(!sound_muted().unwrap_or(false)),
        "bluetooth" => {
            let cur = bt_state_str()?;
            bt_set(!cur.eq_ignore_ascii_case("on"))
        }
        "keyboard" if action == "next" => kbd_next(),
        "brightness" if action == "set" => {
            let v = value.ok_or("brightness needs a value")?;
            bri_set(v.clamp(0, 100) as i32)
        }
        _ => Err(format!("unknown control '{id}' or bad action")),
    }
}

// ================= Windows =================

#[cfg(target_os = "windows")]
fn act_impl(_id: &str, _action: &str, _value: Option<i64>) -> Result<(), String> {
    Err("host controls not supported on windows yet".into())
}
