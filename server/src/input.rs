//! Input injection: translates ClientMessage into enigo calls.
//! Runs on a dedicated thread fed by an mpsc channel so ordering is
//! preserved and enigo's blocking calls stay off the async executor.

use anyhow::Result;
use enigo::{Axis, Button, Coordinate, Direction, Enigo, Key, Keyboard, Mouse, Settings};
use tokio::sync::mpsc;
use tracing::{info, warn};

use crate::protocol::{ButtonState, ClientMessage, KeyState, MouseButton};

/// Spawns the input thread. `tx` is the sending half used by WS handlers.
pub fn spawn_input_thread() -> mpsc::UnboundedSender<ClientMessage> {
    let (tx, mut rx) = mpsc::unbounded_channel::<ClientMessage>();
    std::thread::Builder::new()
        .name("opendeck-input".into())
        .spawn(move || {
            let mut enigo = match Enigo::new(&Settings::default()) {
                Ok(e) => e,
                Err(e) => {
                    warn!("enigo init failed, input disabled: {e}");
                    while rx.blocking_recv().is_some() {}
                    return;
                }
            };
            while let Some(msg) = rx.blocking_recv() {
                if let Err(e) = apply(&mut enigo, &msg) {
                    warn!("input error for {msg:?}: {e}");
                }
            }
        })
        .expect("spawn input thread");
    tx
}

fn direction(state: impl Into<Dir>) -> Direction {
    match state.into() {
        Dir::Down => Direction::Press,
        Dir::Up => Direction::Release,
        Dir::Press => Direction::Click,
    }
}

enum Dir {
    Down,
    Up,
    Press,
}
impl From<ButtonState> for Dir {
    fn from(s: ButtonState) -> Self {
        match s {
            ButtonState::Down => Dir::Down,
            ButtonState::Up => Dir::Up,
        }
    }
}
impl From<KeyState> for Dir {
    fn from(s: KeyState) -> Self {
        match s {
            KeyState::Down => Dir::Down,
            KeyState::Up => Dir::Up,
            KeyState::Press => Dir::Press,
        }
    }
}

fn button(b: MouseButton) -> Result<Button> {
    Ok(match b {
        MouseButton::Left => Button::Left,
        MouseButton::Right => Button::Right,
        MouseButton::Middle => Button::Middle,
        MouseButton::Back => Button::Back,
        MouseButton::Forward => Button::Forward,
    })
}

fn apply(enigo: &mut Enigo, msg: &ClientMessage) -> Result<()> {
    match msg {
        ClientMessage::Hello { name, .. } => {
            info!("client hello: {}", name.as_deref().unwrap_or("unknown"));
        }
        ClientMessage::MouseMove { x, y } => {
            enigo.move_mouse(*x, *y, Coordinate::Abs)?;
        }
        ClientMessage::MouseButton { button: b, state } => {
            enigo.button(button(*b)?, direction(*state))?;
        }
        ClientMessage::Scroll { dx, dy } => {
            if *dy != 0 {
                enigo.scroll(*dy, Axis::Vertical)?;
            }
            if *dx != 0 {
                enigo.scroll(*dx, Axis::Horizontal)?;
            }
        }
        ClientMessage::Key { key, state } => apply_key(enigo, key, *state)?,
        ClientMessage::Text { text } => {
            enigo.text(text)?;
        }
        ClientMessage::Ping => {}
    }
    Ok(())
}

fn apply_key(enigo: &mut Enigo, key: &str, state: KeyState) -> Result<()> {
    // Chord support: "Control+S", "Alt+F4", "Shift+ArrowLeft", ...
    if key.contains('+') {
        let parts: Vec<&str> = key.split('+').collect();
        let (mods, main) = parts.split_at(parts.len() - 1);
        let main_key =
            parse_key(main[0]).ok_or_else(|| anyhow::anyhow!("unknown key '{}'", main[0]))?;
        let mod_keys: Vec<Key> = mods
            .iter()
            .map(|m| parse_key(m))
            .collect::<Option<Vec<_>>>()
            .ok_or_else(|| anyhow::anyhow!("unknown modifier in '{key}'"))?;

        for m in &mod_keys {
            enigo.key(*m, Direction::Press)?;
        }
        let dir = direction(state);
        enigo.key(main_key, dir)?;
        for m in mod_keys.iter().rev() {
            enigo.key(*m, Direction::Release)?;
        }
        return Ok(());
    }

    let k = parse_key(key).ok_or_else(|| anyhow::anyhow!("unknown key '{key}'"))?;
    enigo.key(k, direction(state))?;
    Ok(())
}

fn parse_key(s: &str) -> Option<Key> {
    let lower = s.to_lowercase();
    Some(match lower.as_str() {
        "return" | "enter" => Key::Return,
        "escape" | "esc" => Key::Escape,
        "backspace" => Key::Backspace,
        "tab" => Key::Tab,
        "space" | "spacebar" => Key::Space,
        "delete" | "del" => Key::Delete,
        "insert" | "ins" => return insert_key(),
        "home" => Key::Home,
        "end" => Key::End,
        "pageup" | "pgup" => Key::PageUp,
        "pagedown" | "pgdn" => Key::PageDown,
        "up" | "arrowup" => Key::UpArrow,
        "down" | "arrowdown" => Key::DownArrow,
        "left" | "arrowleft" => Key::LeftArrow,
        "right" | "arrowright" => Key::RightArrow,
        "capslock" => Key::CapsLock,
        "control" | "ctrl" => Key::Control,
        "lcontrol" => Key::LControl,
        "rcontrol" => Key::RControl,
        "alt" | "option" => Key::Alt,
        "shift" => Key::Shift,
        "lshift" => Key::LShift,
        "rshift" => Key::RShift,
        "meta" | "super" | "command" | "cmd" | "win" | "windows" => Key::Meta,
        "volumeup" => Key::VolumeUp,
        "volumedown" => Key::VolumeDown,
        "volumemute" => Key::VolumeMute,
        _ => {
            if let Some(rest) = lower.strip_prefix('f') {
                if let Ok(n) = rest.parse::<u32>() {
                    if (1..=12).contains(&n) {
                        return Some(f_key(n));
                    }
                }
            }
            let mut chars = s.chars();
            match (chars.next(), chars.next()) {
                (Some(c), None) => Key::Unicode(c),
                _ => return None,
            }
        }
    })
}

// enigo only exposes `Key::Insert` on Windows and non-macOS Unix.
#[cfg(any(target_os = "windows", all(unix, not(target_os = "macos"))))]
fn insert_key() -> Option<Key> {
    Some(Key::Insert)
}

#[cfg(not(any(target_os = "windows", all(unix, not(target_os = "macos")))))]
fn insert_key() -> Option<Key> {
    None
}

fn f_key(n: u32) -> Key {
    match n {
        1 => Key::F1,
        2 => Key::F2,
        3 => Key::F3,
        4 => Key::F4,
        5 => Key::F5,
        6 => Key::F6,
        7 => Key::F7,
        8 => Key::F8,
        9 => Key::F9,
        10 => Key::F10,
        11 => Key::F11,
        _ => Key::F12,
    }
}
