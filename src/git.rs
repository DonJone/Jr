use chrono::Local;
use std::path::Path;
use std::process::{Command, Stdio};

#[derive(Debug, PartialEq, Eq)]
pub enum SyncStatus {
    Synced,
    OfflinePending,
    NoChanges,
    GitNotConfigured,
    Error(String),
}

pub fn check_git_installed() -> bool {
    Command::new("git")
        .arg("--version")
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

pub fn check_gh_installed() -> bool {
    Command::new("gh")
        .arg("--version")
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

pub fn check_gh_auth() -> bool {
    Command::new("gh")
        .args(["auth", "status"])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

pub fn do_gh_login() -> bool {
    Command::new("gh")
        .args(["auth", "login"])
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

pub fn is_git_repo(path: &Path) -> bool {
    path.join(".git").exists()
}

pub fn has_git_user_configured(repo_dir: &Path) -> bool {
    let name_ok = Command::new("git")
        .current_dir(repo_dir)
        .args(["config", "user.name"])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false);

    let email_ok = Command::new("git")
        .current_dir(repo_dir)
        .args(["config", "user.email"])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false);

    name_ok && email_ok
}

pub fn get_unpushed_count(repo_dir: &Path) -> usize {
    if !is_git_repo(repo_dir) {
        return 0;
    }
    let output = Command::new("git")
        .current_dir(repo_dir)
        .args(["rev-list", "--count", "@{u}..HEAD"])
        .output();

    if let Ok(out) = output {
        if out.status.success() {
            let s = String::from_utf8_lossy(&out.stdout).trim().to_string();
            return s.parse::<usize>().unwrap_or(0);
        }
    }

    // Fallback: check if ahead of origin/main
    let output2 = Command::new("git")
        .current_dir(repo_dir)
        .args(["cherry", "-v"])
        .output();
    if let Ok(out) = output2 {
        if out.status.success() {
            let s = String::from_utf8_lossy(&out.stdout);
            return s.lines().filter(|l| l.starts_with('+')).count();
        }
    }
    0
}

pub fn init_sync_repo(sync_dir: &Path) -> Result<(), String> {
    if sync_dir.exists() && !is_git_repo(sync_dir) {
        // Recovery logic
        let now_sec = Local::now().timestamp();
        let recovery_path = sync_dir
            .parent()
            .unwrap_or_else(|| Path::new("."))
            .join(format!("Journal_recovery_{}", now_sec));

        std::fs::rename(sync_dir, &recovery_path)
            .map_err(|e| format!("Failed to move sync_dir to recovery: {}", e))?;

        let clone_status = Command::new("gh")
            .args(["repo", "clone", "Journal", sync_dir.to_str().unwrap()])
            .status();

        if clone_status.map(|s| s.success()).unwrap_or(false) {
            // Merge files from recovery
            for entry in walkdir::WalkDir::new(&recovery_path)
                .into_iter()
                .filter_map(|e| e.ok())
            {
                if entry.file_type().is_file()
                    && entry.path().extension().and_then(|s| s.to_str()) == Some("md")
                {
                    if let Ok(rel) = entry.path().strip_prefix(&recovery_path) {
                        let target = sync_dir.join(rel);
                        if let Some(p) = target.parent() {
                            let _ = std::fs::create_dir_all(p);
                        }
                        if target.exists() {
                            let mut target_content =
                                std::fs::read_to_string(&target).unwrap_or_default();
                            let recovery_content =
                                std::fs::read_to_string(entry.path()).unwrap_or_default();
                            target_content.push_str(&format!(
                                "\n--- [Recovered {}] ---\n\n{}",
                                Local::now().format("%Y-%m-%d %H:%M:%S"),
                                recovery_content
                            ));
                            let _ = std::fs::write(&target, target_content);
                        } else {
                            let _ = std::fs::copy(entry.path(), &target);
                        }
                    }
                }
            }
            let _ = std::fs::remove_dir_all(&recovery_path);
            return Ok(());
        } else {
            let _ = std::fs::rename(&recovery_path, sync_dir);
            return Err("Failed to clone remote Journal repo".to_string());
        }
    } else if !sync_dir.exists() {
        if check_gh_installed() {
            let repo_exists = Command::new("gh")
                .args(["repo", "view", "Journal"])
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .status()
                .map(|s| s.success())
                .unwrap_or(false);

            if repo_exists {
                let _ = Command::new("gh")
                    .args(["repo", "clone", "Journal", sync_dir.to_str().unwrap()])
                    .status();
                return Ok(());
            } else {
                let _ = std::fs::create_dir_all(sync_dir);
                let _ = Command::new("git")
                    .current_dir(sync_dir)
                    .args(["init", "-b", "main"])
                    .status();
                let _ = Command::new("git")
                    .current_dir(sync_dir)
                    .args(["commit", "--allow-empty", "-m", "Initial commit"])
                    .status();
                let _ = Command::new("gh")
                    .current_dir(sync_dir)
                    .args(["repo", "create", "Journal", "--private", "--source=.", "--remote=origin", "--push"])
                    .status();
                return Ok(());
            }
        }
    }
    Ok(())
}

pub fn sync_repo(repo_dir: &Path) -> SyncStatus {
    if !is_git_repo(repo_dir) {
        return SyncStatus::NoChanges;
    }

    if !has_git_user_configured(repo_dir) {
        return SyncStatus::GitNotConfigured;
    }

    // git add -A
    let add_status = Command::new("git")
        .current_dir(repo_dir)
        .args(["add", "-A"])
        .status();
    if !add_status.map(|s| s.success()).unwrap_or(false) {
        return SyncStatus::Error("git add failed".to_string());
    }

    // check git status --porcelain
    let status_out = Command::new("git")
        .current_dir(repo_dir)
        .args(["status", "--porcelain"])
        .output();

    let has_uncommitted = match status_out {
        Ok(out) => !out.stdout.is_empty(),
        Err(_) => false,
    };

    if has_uncommitted {
        let commit_msg = format!("jr: {}", Local::now().format("%Y-%m-%d %H:%M:%S"));
        let commit_status = Command::new("git")
            .current_dir(repo_dir)
            .args(["commit", "-m", &commit_msg, "--quiet"])
            .status();

        if !commit_status.map(|s| s.success()).unwrap_or(false) {
            return SyncStatus::Error("git commit failed".to_string());
        }
    }

    // Determine current branch
    let branch_out = Command::new("git")
        .current_dir(repo_dir)
        .args(["branch", "--show-current"])
        .output();
    let branch = match branch_out {
        Ok(out) => {
            let b = String::from_utf8_lossy(&out.stdout).trim().to_string();
            if b.is_empty() { "main".to_string() } else { b }
        }
        Err(_) => "main".to_string(),
    };

    // git pull origin <branch> --rebase
    let pull_status = Command::new("git")
        .current_dir(repo_dir)
        .args(["pull", "origin", &branch, "--rebase", "--quiet"])
        .status();

    let pull_ok = pull_status.map(|s| s.success()).unwrap_or(false);

    // git push -u origin <branch>
    let push_status = Command::new("git")
        .current_dir(repo_dir)
        .args(["push", "-u", "origin", &branch, "--quiet"])
        .status();

    let push_ok = push_status.map(|s| s.success()).unwrap_or(false);

    if push_ok {
        SyncStatus::Synced
    } else if !pull_ok {
        // Pull failed (often offline or no remote yet), push failed too -> pending
        SyncStatus::OfflinePending
    } else {
        SyncStatus::OfflinePending
    }
}
