//! Action engine: named actions the desktop companions (and phones, via the
//! `run_action` WS message) can trigger.
//!
//! Two kinds of action:
//!
//! - `key` — a key chord ("Control+Alt+K", "Return", "a") injected through the
//!   shared input thread, same path as client keystrokes.
//! - `command` — an arbitrary shell command spawned detached.
//!
//! Built-in actions cover media/volume keys. Custom actions load from a JSON
//! file (`--actions <path>`, else `~/.config/opendeck/actions.json`):
//!
//! ```json
//! { "actions": [
//!     { "name": "toggle-dnd", "key": "Control+Alt+D" },
//!     { "name": "grim-screenshot", "command": "grim -g \"$(slurp)\"" }
//! ] }
//! ```

use std::path::Path;
use std::process::Command as ProcCommand;

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use tokio::sync::mpsc;

use crate::protocol::ClientMessage;

#[derive(Debug, Clone)]
pub struct Action {
    pub name: String,
    pub kind: ActionKind,
}

#[derive(Debug, Clone)]
pub enum ActionKind {
    /// Key chord sent through the input thread.
    Key(String),
    /// Shell command spawned detached.
    Command(String),
}

#[derive(Debug, Serialize)]
pub struct ActionInfo {
    pub name: String,
    pub kind: &'static str,
    pub detail: String,
}

const BUILTINS: &[(&str, &str)] = &[
    ("media-play-pause", "MediaPlayPause"),
    ("media-next", "MediaNextTrack"),
    ("media-prev", "MediaPrevTrack"),
    ("volume-up", "VolumeUp"),
    ("volume-down", "VolumeDown"),
    ("volume-mute", "VolumeMute"),
];

#[derive(Deserialize)]
struct ActionsFile {
    #[serde(default)]
    actions: Vec<CustomAction>,
}

#[derive(Deserialize)]
struct CustomAction {
    name: String,
    #[serde(default)]
    key: Option<String>,
    #[serde(default)]
    command: Option<String>,
}

pub struct ActionEngine {
    actions: Vec<Action>,
}

impl ActionEngine {
    /// Load built-ins plus the optional JSON file at `path` (or the default
    /// config location when `path` is None).
    pub fn load(path: Option<&Path>) -> Result<Self> {
        let mut actions: Vec<Action> = BUILTINS
            .iter()
            .map(|(name, key)| Action {
                name: (*name).to_string(),
                kind: ActionKind::Key((*key).to_string()),
            })
            .collect();

        let file_path = path
            .map(|p| p.to_path_buf())
            .or_else(default_config_path)
            .filter(|p| p.is_file());

        if let Some(p) = file_path {
            let text = std::fs::read_to_string(&p)
                .with_context(|| format!("read actions file {}", p.display()))?;
            let parsed: ActionsFile = serde_json::from_str(&text).context("parse actions file")?;
            for a in parsed.actions {
                let kind = match (a.key, a.command) {
                    (Some(k), _) => ActionKind::Key(k),
                    (None, Some(c)) => ActionKind::Command(c),
                    (None, None) => continue,
                };
                actions.push(Action { name: a.name, kind });
            }
        }

        Ok(Self { actions })
    }

    pub fn list(&self) -> Vec<ActionInfo> {
        self.actions
            .iter()
            .map(|a| match &a.kind {
                ActionKind::Key(k) => ActionInfo {
                    name: a.name.clone(),
                    kind: "key",
                    detail: k.clone(),
                },
                ActionKind::Command(c) => ActionInfo {
                    name: a.name.clone(),
                    kind: "command",
                    detail: c.clone(),
                },
            })
            .collect()
    }

    pub fn find(&self, name: &str) -> Option<&Action> {
        self.actions.iter().find(|a| a.name == name)
    }

    /// Execute an action by name.
    pub fn run(&self, name: &str, input_tx: &mpsc::UnboundedSender<ClientMessage>) -> Result<()> {
        let action = self
            .find(name)
            .with_context(|| format!("unknown action '{name}'"))?;
        match &action.kind {
            ActionKind::Key(chord) => {
                input_tx
                    .send(ClientMessage::Key {
                        key: chord.clone(),
                        state: crate::protocol::KeyState::Press,
                    })
                    .context("input thread gone")?;
            }
            ActionKind::Command(cmd) => {
                // Detached: we don't wait for or capture the child's output.
                ProcCommand::new("sh")
                    .args(["-c", cmd])
                    .stdin(std::process::Stdio::null())
                    .stdout(std::process::Stdio::null())
                    .stderr(std::process::Stdio::null())
                    .spawn()
                    .with_context(|| format!("spawn command '{cmd}'"))?;
            }
        }
        Ok(())
    }
}

fn default_config_path() -> Option<std::path::PathBuf> {
    let base = std::env::var_os("XDG_CONFIG_HOME")
        .map(std::path::PathBuf::from)
        .or_else(|| {
            std::env::var_os("HOME").map(|h| std::path::PathBuf::from(h).join(".config"))
        })?;
    Some(base.join("opendeck").join("actions.json"))
}
