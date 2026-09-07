# Jr v3.0 现代化升级方案架构设计 (Rust Rewrite)

## 1. 项目定位与核心哲学
`jr` (Journal CLI) 自诞生以来的核心哲学是：**“做一件事，并做好它 (Do one thing and do it well)”**。
- **输入即记录，零摩擦**：毫秒级启动，终端直接记录并安全退出。
- **Markdown 即格式，可读可迁移**：年/月/日分层纯文本存储，格式完全透明。
- **Git 即同步，冲突自愈**：利用 Git 版本控制进行多设备同步。
- **物理隔离即安全**：敏感信息隔离区永不触网。

在 **v3.0.0** 现代化升级中，我们保留所有原有行为与兼容性，同时全面拥抱 Rust 生态，将 Jr 升级为现代、类型安全、高性能的高颜值终端工具。

---

## 2. 升级核心维度

### 2.1 终端直读与检索 (Terminal-native Reading & Query)
* **痛点**：v2.0 只能写不能读，看日志必须调用外部 GUI/TUI 编辑器。
* **v3.0 方案**：
  - `jr view` / `jr today` / `jr -t`：在终端直接优雅渲染今日日志，带彩色标题、时间戳徽标、语法高亮与行号。
  - `jr yesterday`：一键查看昨天的记录。
  - `jr date <YYYY-MM-DD>`：按日期直读。
  - `jr tail [N]`：快速查看最近 N 条记录。
  - `jr list`：列出最近所有日志文件及记录数。
  - `jr search <query>`：基于正则/关键字的闪电全文搜索，智能高亮匹配行及上下文字符。
  - `jr tags`：自动解析并统计日志中以 `#tag` 标记的话题与计数。
  - `jr stats`：展示日志总条数、连续打卡天数 (Streak)、年度/月度统计看板。

### 2.2 鲁棒离线模式与智能 Git 同步 (Offline-first & Resilient Sync)
* **痛点**：v2.0 无网或 GitHub 网络抖动时，`git pull`/`push` 报错并中断用户记录心流。
* **v3.0 方案**：
  - **离线降级 (Graceful Offline Fallback)**：日志秒级写入本地并完成本地 Git Commit。若网络探测超时或 Git 远程交互失败，记录本地标记“待同步 (Pending Push)”，友好提醒用户而绝不中断退出。
  - **独立同步命令 `jr sync`**：支持随时随地手动触发拉取 (`pull --rebase`) 与推送 (`push`)。
  - **网络恢复静默同步**：当用户在连网后执行任何写入或 `jr sync` 时，自动合并提交并补推。

### 2.3 现代化 CLI 交互与编辑器配置
* **痛点**：v2.0 拥有硬编码参数（`-c`, `-g`, `-k`, `-m`, `-x`），灵活性低，无法自由适配 Neovim / Helix / Emacs 等。
* **v3.0 方案**：
  - 环境变量 `$VISUAL`、`$EDITOR` 自动检测。
  - 支持 `~/.config/jr/config.toml` 与旧版 `~/.config/jr/config` 无缝兼容，可在配置文件中指定 `editor = "nvim"`。
  - 保留 `-c, --code`, `-m, --macos`, `-e, --edit` 等所有旧版参数以保障 100% 向后兼容。

### 2.4 现代 CLI 生态与工程化
* **Shell 自动补全**：内置生成 Bash、Zsh、Fish 自动补全脚本 (`jr completions <shell>`)。
* **自升级支持**：新增 `jr update` / `jr upgrade` 命令，检查并拉取最新发布。
* **测试与 CI/CD**：
  - 完善的 Rust 单元测试与端到端集成测试 (`cargo test`)。
  - GitHub Actions CI 工作流 (`.github/workflows/ci.yml`)，覆盖 Linux、macOS (Intel/Apple Silicon) 与 Windows 的交叉编译自动化构建与发布。

---

## 3. 命令行参数接口设计

```text
jr [OPTIONS] [CONTENT]
jr <COMMAND>

Commands:
  view (today, t)       View today's journal entries in terminal
  yesterday (y)         View yesterday's journal entries
  date <YYYY-MM-DD>     View journal entries for a specific date
  tail [N]              Show the last N journal entries (default: 5)
  list (ls)             List recent journal files
  search (grep) <QUERY> Search journal entries across all files
  tags                  List all hashtags used in journals
  sync                  Perform full bidirectional Git sync
  stats                 Display journal statistics and streak
  login                 Interactive GitHub CLI authentication
  status                Display system, repository, and auth status
  completions <SHELL>   Generate shell completion script (bash, zsh, fish)
  upgrade (update)      Check and upgrade jr to the latest version

Options:
  -l, --local           Record to local backup only
  -p, --private         Record to private zone (never synced)
  -c, --code            Open in VS Code
  -m, --macos           Open in macOS TextEdit
  -e, --edit            Open in default editor ($EDITOR / $VISUAL)
  -g, --gnome           Open in GNOME Text Editor
  -k, --kde             Open in Kate
  -x, --xdg             Open with xdg-open
  -q, --quiet           Quiet mode (suppress unnecessary output)
  -v, --verbose         Verbose / debug mode
  -V, --version         Show version information
  -h, --help            Show help
```

---

## 4. 目录结构与向下兼容性

目录格式保持完全一致：
```
~/Documents/
├── Journal/              # 云端同步区 (Git 托管)
│   └── 2026/05/
│       └── 2026-05-04.md
├── Journal_local/        # 本地备份区
│   └── 2026/05/
│       └── 2026-05-04_local.md
└── Journal_private/      # 隔离区 (永不上传)
    └── 2026/05/
        └── 2026-05-04_private.md
```

配置文件兼容性：
1. 优先读取 `~/.config/jr/config.toml`
2. 兼容读取旧版 shell 语法配置 `~/.config/jr/config`
