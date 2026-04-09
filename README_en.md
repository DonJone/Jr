[中文版本](README.md)

# JR (Journal CLI)

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
![Platform: Linux | macOS](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-lightgrey.svg)

`jr` is a minimalist terminal journal solution designed for developers who pursue "certainty" and "efficiency". Distinct from bloated and comprehensive note-taking applications, the core design philosophy of `jr` lies in providing robust underlying logic. Through engineering approaches, it thoroughly resolves the core pain points encountered during multi-device journal synchronization, such as Git conflicts, environment corruption, and privacy data leaks.

## One-Click Installation
The installation script is idempotent. It automatically detects Bash/Zsh, safely injects PATH configurations, and prevents duplicate writes.
```bash
/bin/bash -c "$(curl -fsSL [https://raw.githubusercontent.com/DonJone/jr/main/install.sh](https://raw.githubusercontent.com/DonJone/jr/main/install.sh))"
```


## One-Click Installation
The installation script is idempotent. It automatically detects Bash/Zsh, safely injects PATH configurations, and prevents duplicate writes.
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/DonJone/jr/main/install.sh)"
```
## System Architecture & Dependencies

**Dependencies:**
- Base Components: `git`, `curl`
- Enhanced Components: `gh` (GitHub CLI - used to drive automated synchronization and environment self-healing modules)

**Directory Topology:**
```text
~/Documents/
├── Journal/                 # Sync Zone (Managed by Git/GitHub)
│   └── 2026/04/             # Auto-layered by Year/Month
│       └── 2026-04-09.md    # Cloud journal file
└── Journal_local/           # Local backup and non-uploaded journals
    └── 2026/04/
        └── 2026-04-09_local.md
```

## Quick Start

- `jr` will automatically create the local directories and a GitHub private repository upon initialization.
- `jr --help` : View the CLI help manual.
- `jr text` : Quickly record a journal entry.
- `jr -c` : Use the code editor to edit the journal.
- `jr -l` : Record in the local directory only.
- `jr -l -c` : Use the code editor to edit the journal, recording in the local directory only.


## One-Click Uninstallation
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/DonJone/jr/main/uninstall.sh)"
```

## License

This project is open-sourced under the [GNU Affero General Public License v3.0 (AGPL-3.0)](https://www.gnu.org/licenses/agpl-3.0).