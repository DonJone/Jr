English | [中文](README.md)

# jr

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-lightgrey.svg)
![Version](https://img.shields.io/badge/version-3.0.0-green.svg)
![Rust](https://img.shields.io/badge/built_with-Rust-orange.svg)

A minimalist, modern terminal journal for developers who think in the terminal.

`jr` does not attempt to become another bloated note-taking app. It follows the Unix philosophy: **do one thing and do it well**.
Record thoughts at terminal speed, preview and search directly inside the terminal without waking up a heavy editor, safely cache offline, and sync seamlessly with Git.

---

## ✨ Core Features

- ⚡ **Zero Friction**: Rewritten in Rust with sub-millisecond cold start. Supports instant arguments and pipe stdin.
- 📖 **Terminal-native Reading**: Built-in `jr view`, `jr today`, `jr yesterday`, `jr tail` with colored timeline rendering.
- 🔍 **Lightning Search & Tags**: Full-text `jr search <query>` with highlighted context; native `#tag` extraction and aggregation via `jr tags`.
- 📊 **Streak & Dashboard**: `jr stats` displays your consecutive streak, total word count, top tags cloud, and monthly heatmap.
- 🔄 **Resilient Sync**: Offline-first design commits locally without blocking your flow; automatically pushes when connected or via `jr sync`.
- 🛡 **Physical Isolation**: Three-tier zones (Sync, Local Backup, Private Isolation). Sensitive data never touches the network.
- 🧩 **Shell Autocompletions**: Native generation for Zsh, Bash, and Fish.
- ⚙️ **Editor Freedom**: Full support for TOML config, automatic `$VISUAL` / `$EDITOR` detection, and 100% backward compatibility with legacy flags.

---

## 🚀 Installation

### One-line Script
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/DonJone/jr/main/install.sh)"
```

### Build from Source
```bash
git clone https://github.com/DonJone/jr.git
cd jr
cargo install --path .
```

---

## 📖 Quick Start

### 1. Recording
```bash
# Record to sync zone + local backup
jr "Refactored auth module today #rust #dev"

# Pipe output from commands
echo "Daily build completed" | jr

# Record to local backup only
jr -l "Local debugging notes"

# Record to private zone (isolated, never uploaded)
jr -p "Server staging password: abc-123"
```

### 2. Reading in Terminal
```bash
# View today's entries
jr view

# View yesterday's entries
jr yesterday

# View a specific date
jr date 2026-05-04

# View the last 5 entries
jr tail 5

# List recent journal files
jr list
```

### 3. Searching & Tags
```bash
# Full-text search with highlights
jr search "auth module"

# View all tags and frequencies
jr tags

# Filter entries by tag
jr tag rust
```

### 4. Stats & Dashboard
```bash
jr stats
```

### 5. Sync & Status
```bash
# Check status and pending commits
jr status

# Trigger full bidirectional sync
jr sync

# Authenticate with GitHub
jr login
```

### 6. External Editors
```bash
# Open today's journal in $EDITOR
jr -e

# Open in VS Code
jr -c
```

---

## ⚙️ Configuration

Config file: `~/.config/jr/config.toml` (also backwards-compatible with legacy `~/.config/jr/config`)

```toml
sync_dir = "~/Documents/Journal"
local_dir = "~/Documents/Journal_local"
private_dir = "~/Documents/Journal_private"
editor = "nvim"
auto_sync = true
```

---

## 🐚 Completions

Generate shell completions:
```bash
# Zsh
jr completions zsh > ~/.zsh/completions/_jr

# Bash
jr completions bash > ~/.bash_completion.d/jr

# Fish
jr completions fish > ~/.config/fish/completions/jr.fish
```

---

## 🗑️ Uninstallation

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/DonJone/jr/main/uninstall.sh)"
```

> [!NOTE]
> Uninstallation removes the executable and configurations only. Your journal files in `~/Documents/` are **never deleted**.

---

## 📄 License

[AGPL-3.0](LICENSE)
