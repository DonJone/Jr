[English](README_en.md) | 中文

# jr

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-lightgrey.svg)
![Version](https://img.shields.io/badge/version-3.0.0-green.svg)
![Rust](https://img.shields.io/badge/built_with-Rust-orange.svg)

极简主义的现代化终端日志工具，专为习惯用终端思考的开发者打造。

`jr` 不试图成为臃肿的笔记应用。它遵循 Unix 哲学：**做一件事，并做好它**。
让你在终端里极速记录灵感与日志，支持免编辑器直接在终端预览与检索，离线安全暂存，联网自动通过 Git 同步。

---

## ✨ 核心特性

- ⚡ **输入即记录，零摩擦**：Rust 重构核心，亚毫秒级冷启动，支持参数直接记录与管道流式输入。
- 📖 **终端直读与高颜值排版**：内置 `jr view`、`jr today`、`jr yesterday`、`jr tail`，彩色徽标与时间线渲染，无需唤醒笨重编辑器。
- 🔍 **闪电全文搜索与标签聚合**：`jr search <query>` 高亮匹配上下文；原生支持 `#tag` 语法与 `jr tags` 标签聚类统计。
- 📊 **打卡统计与活跃看板**：`jr stats` 直观展示连续打卡天数 (Streak)、历史总字数、高频标签云与月度活跃走势。
- 🔄 **智能离线容错与 Git 同步**：无网时优雅降级为本地已提交，不中断用户心流；联网后静默补推，支持 `jr sync` 手动全量同步。
- 🛡 **物理隔离即安全**：三级目录管理（云端同步区、本地备份区、隔离区），敏感凭证永不触网。
- 🧩 **全 Shell 自动补全**：内置原生 Zsh、Bash、Fish 自动补全生成器。
- ⚙️ **现代编辑器与配置自由**：支持 TOML 现代配置，自动识别 `$VISUAL` / `$EDITOR`，保留全量旧版快捷参数兼容。

---

## 🚀 安装

### 一键安装脚本
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/DonJone/jr/main/install.sh)"
```

脚本将自动检测系统架构、安装预编译二进制文件、配置 PATH 环境变量与 Shell 补全，并引导 GitHub 授权。

### 源码编译安装 (可选)
如果你本地已安装 Rust / Cargo：
```bash
git clone https://github.com/DonJone/jr.git
cd jr
cargo install --path .
```

---

## 📖 快速上手

### 1. 快速记录
```bash
# 记录一条日常日志（写入同步区 + 本地备份）
jr "今天完成了认证模块重构 #rust #dev"

# 从管道读取命令输出
echo "自动化备份完成" | jr

# 仅记录到本地备份（不上传至云端）
jr -l "本地网络调试记录"

# 记录到隔离区（永不上传，物理隔离）
jr -p "服务器跳板机临时密码: abc-123"
```

### 2. 终端直接阅读
```bash
# 预览今天的日志（带彩色时间线）
jr view
# 或简写
jr today

# 查看昨天的日志
jr yesterday

# 查看指定日期的日志
jr date 2026-05-04

# 查看最近 5 条日志记录
jr tail 5

# 列出近期的日志文件与摘要
jr list
```

### 3. 搜索与标签
```bash
# 全文搜索关键字并高亮匹配
jr search "认证模块"

# 查看所有使用过的标签与词频
jr tags

# 按标签检索相关日志
jr tag rust
```

### 4. 数据看板与统计
```bash
# 查看打卡连续天数、总条数、月度走势图
jr stats
```

### 5. 同步与状态
```bash
# 检查当前状态（GitHub 认证、未推送提交、文件统计）
jr status

# 手动触发双向 Git 同步
jr sync

# 授权 GitHub CLI 登录
jr login
```

### 6. 编辑器打开
```bash
# 使用配置编辑器或 $EDITOR 打开今天的日志
jr -e

# 指定编辑器打开
jr -c   # VS Code
jr -m   # macOS TextEdit
jr -g   # GNOME Text Editor
```

---

## 📁 目录结构

`jr` 保持纯文本 Markdown 结构，无任何私有数据库锁定：

```
~/Documents/
├── Journal/              # 同步区 → 自动 Git 托管与同步
│   └── 2026/05/
│       └── 2026-05-04.md
├── Journal_local/        # 本地备份区（有网时也会同步）
│   └── 2026/05/
│       └── 2026-05-04_local.md
└── Journal_private/      # 隔离区（永不上传）
    └── 2026/05/
        └── 2026-05-04_private.md
```

---

## ⚙️ 配置说明

配置文件路径：`~/.config/jr/config.toml`（同时无缝兼容旧版 `~/.config/jr/config`）

```toml
# 自定义目录存储路径
sync_dir = "~/Documents/Journal"
local_dir = "~/Documents/Journal_local"
private_dir = "~/Documents/Journal_private"

# 默认偏好编辑器 (如 nvim, code, helix, nano)
editor = "nvim"

# 写入后是否自动触发 git push 同步
auto_sync = true
```

---

## 🐚 Shell 自动补全

如果你使用了自定义 Shell 配置，可随时生成补全脚本：
```bash
# Zsh
jr completions zsh > ~/.zsh/completions/_jr

# Bash
jr completions bash > ~/.bash_completion.d/jr

# Fish
jr completions fish > ~/.config/fish/completions/jr.fish
```

---

## 🗑️ 卸载

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/DonJone/jr/main/uninstall.sh)"
```
> [!NOTE]
> 卸载仅移除程序与配置文件，**绝不会删除**你位于 `~/Documents/` 中的任何日志数据。

---

## 📄 开源协议

[AGPL-3.0](LICENSE)
