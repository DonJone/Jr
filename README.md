
[English Version](README_en.md)

# JR (Journal CLI)

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
![Platform: Linux | macOS](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-lightgrey.svg)

jr 是一款为追求“确定性”与“效率”的开发者打造的极简终端日志方案。有别于大而全的笔记应用，jr 的核心设计哲学在于提供稳健的底层逻辑，通过工程化手段彻底解决多设备日志同步时的 Git 冲突、环境损坏以及隐私数据泄露等核心痛点。


## 一键安装
安装脚本具备幂等性，自动识别 Bash/Zsh 并安全注入 PATH 配置，防重复写入。
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/DonJone/jr/main/install.sh)"
```

## 核心特性

- **轻量与便捷性**
  采用md格式记录日志文件，输入命令与文本即可记录
- **双模存储与目录隔离**
  支持云端同步与本地物目录两种模式。敏感信息可被强制写入隔离目录，确保不被 Git 追踪，实现物理级的数据安全。
- **并发安全与环境自愈**
  内置基于 `flock` 的文件锁机制，从底层杜绝多实例并发操作导致的 Git 索引锁定。具备 `.git` 目录损坏检测能力，遇到异常可自动完成数据备份、仓库重构及合并。
- **阻塞式编辑器集成**
  原生支持 Code OSS, Kate, GNOME Text Editor, macOS TextEdit 等主流编辑器。采用严格的阻塞式执行逻辑，确保主进程等待编辑器关闭后再触发 Git 同步生命周期，保证数据完整性。
- **自动化运维**
  零配置开箱即用。自动识别系统 `$LANG` 提供本地化交互，并根据时间戳（年/月）自动构建分层级目录结构。

## 系统架构与依赖

**依赖组件：**
- 基础组件：`git`, `curl`
- 增强组件：`gh` (GitHub CLI - 用于驱动自动同步与环境自愈模块)

**目录拓扑结构：**
```text
~/Documents/
├── Journal/                 # 同步区 (由 Git/GitHub 接管)
│   └── 2026/04/             # 年/月自动分层
│       └── 2026-04-09.md    # 云端日志文件
└── Journal_local/           # 本地备份与非上传日志
    └── 2026/04/
        └── 2026-04-09_local.md
```

## 快速入门

- jr 将创建本地目录与GitHub私人仓库
- jr --help  查阅 CLI 帮助手册
- jr text 快速记录
- jr -c 使用code 编辑日志
- jr -l 仅在本地目录记录
- jr -l -c 使用code 编辑日志,仅在本地目录记录


## 一键卸载
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/DonJone/jr/main/uninstall.sh)"
```



## 开源协议声明组件 (License)

许可证
本项目基于 [GNU Affero General Public License v3.0 (AGPL-3.0)](https://www.gnu.org/licenses/agpl-3.0) 开源。