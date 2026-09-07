use std::env;
use std::path::Path;
use std::process::Command;

use crate::config::Config;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EditorFlag {
    Code,
    Gnome,
    Kde,
    Macos,
    Edit,
    Xdg,
}

pub fn open_in_editor(
    file_path: &Path,
    editor_flag: Option<EditorFlag>,
    config: &Config,
    is_en: bool,
) -> Result<(), String> {
    let file_str = file_path.to_str().ok_or("Invalid file path")?;

    let (prog, args): (String, Vec<String>) = match editor_flag {
        Some(EditorFlag::Code) => {
            ("code".to_string(), vec!["--wait".to_string(), file_str.to_string()])
        }
        Some(EditorFlag::Gnome) => {
            let prog = if which::which("gnome-text-editor").is_ok() {
                "gnome-text-editor".to_string()
            } else {
                "gedit".to_string()
            };
            (prog, vec![file_str.to_string()])
        }
        Some(EditorFlag::Kde) => {
            ("kate".to_string(), vec!["--new".to_string(), "--block".to_string(), file_str.to_string()])
        }
        Some(EditorFlag::Macos) => {
            ("open".to_string(), vec!["-W".to_string(), "-t".to_string(), file_str.to_string()])
        }
        Some(EditorFlag::Xdg) => {
            ("xdg-open".to_string(), vec![file_str.to_string()])
        }
        Some(EditorFlag::Edit) | None => {
            // Determine configured or env editor
            if let Some(ref ed) = config.editor {
                let parts: Vec<String> = ed.split_whitespace().map(|s| s.to_string()).collect();
                if let Some((first, rest)) = parts.split_first() {
                    let mut args = rest.to_vec();
                    args.push(file_str.to_string());
                    (first.clone(), args)
                } else {
                    (ed.clone(), vec![file_str.to_string()])
                }
            } else if let Ok(vis) = env::var("VISUAL") {
                (vis, vec![file_str.to_string()])
            } else if let Ok(ed) = env::var("EDITOR") {
                (ed, vec![file_str.to_string()])
            } else if cfg!(target_os = "macos") {
                ("open".to_string(), vec!["-t".to_string(), file_str.to_string()])
            } else if Command::new("xdg-open").arg("--version").output().is_ok() {
                ("xdg-open".to_string(), vec![file_str.to_string()])
            } else {
                ("vi".to_string(), vec![file_str.to_string()])
            }
        }
    };

    let status = Command::new(&prog)
        .args(&args)
        .status()
        .map_err(|e| {
            let err_prefix = if is_en { "Failed to start editor" } else { "无法启动编辑器" };
            format!("{} '{}': {}", err_prefix, prog, e)
        })?;

    if !status.success() {
        let err_prefix = if is_en { "Editor exited with error" } else { "编辑器异常退出" };
        return Err(format!("{}: {:?}", err_prefix, status.code()));
    }

    Ok(())
}

mod which {
    use std::env;
    use std::path::PathBuf;

    pub fn which(cmd: &str) -> Result<PathBuf, ()> {
        if let Ok(paths) = env::var("PATH") {
            for p in env::split_paths(&paths) {
                let full = p.join(cmd);
                if full.is_file() {
                    return Ok(full);
                }
            }
        }
        Err(())
    }
}
