use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    #[serde(default = "default_sync_dir")]
    pub sync_dir: PathBuf,

    #[serde(default = "default_local_dir")]
    pub local_dir: PathBuf,

    #[serde(default = "default_private_dir")]
    pub private_dir: PathBuf,

    #[serde(default)]
    pub editor: Option<String>,

    #[serde(default = "default_auto_sync")]
    pub auto_sync: bool,
}

fn home_dir() -> PathBuf {
    dirs::home_dir().unwrap_or_else(|| PathBuf::from("."))
}

fn default_sync_dir() -> PathBuf {
    home_dir().join("Documents").join("Journal")
}

fn default_local_dir() -> PathBuf {
    home_dir().join("Documents").join("Journal_local")
}

fn default_private_dir() -> PathBuf {
    home_dir().join("Documents").join("Journal_private")
}

fn default_auto_sync() -> bool {
    true
}

impl Default for Config {
    fn default() -> Self {
        Self {
            sync_dir: default_sync_dir(),
            local_dir: default_local_dir(),
            private_dir: default_private_dir(),
            editor: None,
            auto_sync: true,
        }
    }
}

impl Config {
    pub fn config_dir() -> PathBuf {
        if let Ok(xdg) = env::var("XDG_CONFIG_HOME") {
            PathBuf::from(xdg).join("jr")
        } else {
            home_dir().join(".config").join("jr")
        }
    }

    pub fn toml_path() -> PathBuf {
        Self::config_dir().join("config.toml")
    }

    pub fn legacy_path() -> PathBuf {
        Self::config_dir().join("config")
    }

    pub fn expand_path(p: &Path) -> PathBuf {
        let s = p.to_string_lossy();
        if s.starts_with("~/") {
            home_dir().join(s.strip_prefix("~/").unwrap())
        } else if s.starts_with("$HOME/") {
            home_dir().join(s.strip_prefix("$HOME/").unwrap())
        } else if s == "~" || s == "$HOME" {
            home_dir()
        } else {
            p.to_path_buf()
        }
    }

    pub fn load() -> Self {
        let mut config = Config::default();

        // 1. Try TOML config first
        let toml_file = Self::toml_path();
        if toml_file.exists() {
            if let Ok(content) = fs::read_to_string(&toml_file) {
                if let Ok(parsed) = toml::from_str::<Config>(&content) {
                    config = parsed;
                }
            }
        } else {
            // 2. Try legacy config format: key="value" or key=value
            let legacy_file = Self::legacy_path();
            if legacy_file.exists() {
                if let Ok(content) = fs::read_to_string(&legacy_file) {
                    for line in content.lines() {
                        let trimmed = line.trim();
                        if trimmed.is_empty() || trimmed.starts_with('#') {
                            continue;
                        }
                        if let Some((k, v)) = trimmed.split_once('=') {
                            let key = k.trim();
                            let val = v.trim().trim_matches('"').trim_matches('\'');
                            match key {
                                "sync_dir" => config.sync_dir = PathBuf::from(val),
                                "local_dir" => config.local_dir = PathBuf::from(val),
                                "private_dir" => config.private_dir = PathBuf::from(val),
                                "editor" => config.editor = Some(val.to_string()),
                                "auto_sync" => config.auto_sync = val != "false" && val != "0",
                                _ => {}
                            }
                        }
                    }
                }
            }
        }

        // 3. Environment variables overrides
        if let Ok(sync) = env::var("JRNL_SYNC") {
            config.sync_dir = PathBuf::from(sync);
        }
        if let Ok(local) = env::var("JRNL_LOCAL") {
            config.local_dir = PathBuf::from(local);
        }
        if let Ok(private) = env::var("JRNL_PRIVATE") {
            config.private_dir = PathBuf::from(private);
        }

        // Expand paths
        config.sync_dir = Self::expand_path(&config.sync_dir);
        config.local_dir = Self::expand_path(&config.local_dir);
        config.private_dir = Self::expand_path(&config.private_dir);

        config
    }

    pub fn ensure_config_exists() -> Result<(), std::io::Error> {
        let dir = Self::config_dir();
        if !dir.exists() {
            fs::create_dir_all(&dir)?;
        }
        let toml_file = Self::toml_path();
        let legacy_file = Self::legacy_path();
        if !toml_file.exists() && !legacy_file.exists() {
            let default_toml = r#"# jr configuration file (v3.0.0)
# Uncomment and modify to customize paths and preferences

# sync_dir = "~/Documents/Journal"
# local_dir = "~/Documents/Journal_local"
# private_dir = "~/Documents/Journal_private"
# editor = "nvim" # or "code", "nano", "vim", etc.
# auto_sync = true
"#;
            fs::write(toml_file, default_toml)?;
        }
        Ok(())
    }
}
