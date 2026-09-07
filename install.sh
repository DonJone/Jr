#!/bin/bash

# ==========================================
# jr - Journal CLI Installer v3.0.0
# ==========================================
# High-performance, minimalist terminal journal
# https://github.com/DonJone/jr

set -euo pipefail

# ==========================================
# Constants
# ==========================================
readonly VERSION="3.0.0"
readonly GITHUB_REPO="DonJone/jr"
readonly BIN_DIR="$HOME/.local/bin"
readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/jr"
readonly CONFIG_FILE="$CONFIG_DIR/config.toml"
readonly TARGET="$BIN_DIR/jr"

# ==========================================
# Color & Output
# ==========================================
if [[ -t 1 ]]; then
    readonly BLUE='\033[0;34m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly RED='\033[0;31m'
    readonly CYAN='\033[0;36m'
    readonly BOLD='\033[1m'
    readonly DIM='\033[2m'
    readonly NC='\033[0m'
else
    readonly BLUE=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly RED=''
    readonly CYAN=''
    readonly BOLD=''
    readonly DIM=''
    readonly NC=''
fi

# ==========================================
# Language Detection
# ==========================================
detect_language() {
    [[ "${LANG:-}" =~ ^en ]] || \
    [[ "${LC_ALL:-}" =~ ^en ]] || \
    [[ "${LC_MESSAGES:-}" =~ ^en ]] && echo "en" || echo "zh"
}

LANG_CODE=$(detect_language)

init_i18n() {
    if [[ "$LANG_CODE" == "en" ]]; then
        STR_WELCOME="Welcome to jr - Journal CLI v3.0.0 Installer"
        STR_CHECKING="Checking system environment..."
        STR_DEPS_OK="All dependencies satisfied"
        STR_INSTALLING="Installing jr binary..."
        STR_INSTALL_OK="jr installed successfully to $TARGET"
        STR_INSTALL_FAIL="Installation failed"
        STR_PATH_CONFIG="Configuring PATH..."
        STR_PATH_OK="PATH configured"
        STR_PATH_EXISTS="PATH already configured"
        STR_COMPLETIONS="Installing shell completions..."
        STR_COMPLETIONS_OK="Shell completions installed"
        STR_CONFIG_CREATING="Creating configuration file..."
        STR_CONFIG_OK="Configuration file ready ($CONFIG_FILE)"
        STR_TESTING="Running self-test..."
        STR_TEST_OK="Verification test passed"
        STR_DONE="Installation complete!"
        STR_USAGE_HINT="Run 'jr --help' to explore commands"
    else
        STR_WELCOME="欢迎安装 jr - 极简现代化终端日志工具 v3.0.0"
        STR_CHECKING="正在检查系统环境与依赖..."
        STR_DEPS_OK="核心依赖已就绪"
        STR_INSTALLING="正在安装 jr 二进制可执行文件..."
        STR_INSTALL_OK="jr 已成功安装至 $TARGET"
        STR_INSTALL_FAIL="安装失败"
        STR_PATH_CONFIG="正在配置 PATH 环境变量..."
        STR_PATH_OK="PATH 已配置"
        STR_PATH_EXISTS="PATH 中已包含 $BIN_DIR"
        STR_COMPLETIONS="正在安装 Shell 自动补全脚本..."
        STR_COMPLETIONS_OK="Shell 自动补全配置完成"
        STR_CONFIG_CREATING="正在初始化配置文件..."
        STR_CONFIG_OK="配置文件已就绪 ($CONFIG_FILE)"
        STR_TESTING="正在运行功能验证测试..."
        STR_TEST_OK="验证测试通过"
        STR_DONE="安装完成！"
        STR_USAGE_HINT="运行 'jr --help' 查看命令指南"
    fi
}

print_banner() {
    echo ""
    echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${BOLD}jr${NC} - Journal CLI ${GREEN}v${VERSION}${NC} (Rust Core)    ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${DIM}A modern terminal journal for developers${NC} ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}└─────────────────────────────────────────┘${NC}"
    echo ""
}

print_step() { echo -e "  ${BLUE}▸${NC} $*"; }
print_success() { echo -e "  ${GREEN}✓${NC} $*"; }
print_warn() { echo -e "  ${YELLOW}!${NC} $*"; }
print_error() { echo -e "  ${RED}✗${NC} $*"; }
print_info() { echo -e "  ${DIM}$*${NC}"; }

detect_target() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)

    case "$os" in
        darwin)
            case "$arch" in
                arm64|aarch64) echo "aarch64-apple-darwin" ;;
                x86_64) echo "x86_64-apple-darwin" ;;
                *) echo "unknown" ;;
            esac
            ;;
        linux)
            case "$arch" in
                x86_64) echo "x86_64-unknown-linux-gnu" ;;
                aarch64|arm64) echo "aarch64-unknown-linux-gnu" ;;
                *) echo "unknown" ;;
            esac
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

install_binary() {
    print_step "$STR_INSTALLING"
    mkdir -p "$BIN_DIR"

    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
    
    # Check if local compiled release binary exists
    if [[ -n "$script_dir" ]] && [[ -x "$script_dir/target/release/jr" ]]; then
        cp "$script_dir/target/release/jr" "$TARGET"
        chmod +x "$TARGET"
        print_success "$STR_INSTALL_OK (local build)"
        return 0
    fi

    # Check if cargo is available to build from source if inside repo
    if [[ -n "$script_dir" ]] && [[ -f "$script_dir/Cargo.toml" ]] && command -v cargo >/dev/null 2>&1; then
        print_info "Compiling release binary with cargo..."
        (cd "$script_dir" && cargo build --release --quiet)
        cp "$script_dir/target/release/jr" "$TARGET"
        chmod +x "$TARGET"
        print_success "$STR_INSTALL_OK (compiled with cargo)"
        return 0
    fi

    # Download from GitHub Release
    local target_arch=$(detect_target)
    if [[ "$target_arch" == "unknown" ]]; then
        print_error "Unsupported platform: $(uname -s) $(uname -m)"
        exit 1
    fi

    local release_url="https://github.com/${GITHUB_REPO}/releases/latest/download/jr-${target_arch}.tar.gz"
    local tmp_dir=$(mktemp -d)
    
    print_info "Downloading $release_url..."
    if curl -fsSL "$release_url" -o "$tmp_dir/jr.tar.gz" 2>/dev/null; then
        tar -xzf "$tmp_dir/jr.tar.gz" -C "$tmp_dir"
        cp "$tmp_dir/jr-${target_arch}/jr" "$TARGET"
        chmod +x "$TARGET"
        rm -rf "$tmp_dir"
        print_success "$STR_INSTALL_OK"
        return 0
    else
        # Fallback: check if legacy jr script is available
        if [[ -f "$script_dir/legacy/jr.v2.sh" ]]; then
            print_warn "Release binary download failed. Falling back to legacy shell script."
            cp "$script_dir/legacy/jr.v2.sh" "$TARGET"
            chmod +x "$TARGET"
            print_success "$STR_INSTALL_OK (legacy script)"
            rm -rf "$tmp_dir"
            return 0
        fi
        rm -rf "$tmp_dir"
        print_error "$STR_INSTALL_FAIL"
        exit 1
    fi
}

configure_path() {
    print_step "$STR_PATH_CONFIG"
    if [[ ":$PATH:" == *":$BIN_DIR:"* ]]; then
        print_success "$STR_PATH_EXISTS"
        return 0
    fi

    local current_shell=$(basename "$SHELL")
    local rc_file=""
    case "$current_shell" in
        zsh)  rc_file="$HOME/.zshrc" ;;
        bash) rc_file="$HOME/.bashrc" ;;
        *)    rc_file="$HOME/.profile" ;;
    esac

    if [[ -f "$rc_file" ]] && grep -q "\.local/bin" "$rc_file" 2>/dev/null; then
        print_success "$STR_PATH_EXISTS"
        return 0
    fi

    echo "" >> "$rc_file"
    echo "# jr CLI path" >> "$rc_file"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc_file"
    print_success "$STR_PATH_OK ($rc_file)"
}

install_completions() {
    if [[ ! -x "$TARGET" ]]; then return 0; fi
    print_step "$STR_COMPLETIONS"

    # Zsh
    local zsh_comp_dir="$HOME/.zsh/completions"
    mkdir -p "$zsh_comp_dir"
    "$TARGET" completions zsh > "$zsh_comp_dir/_jr" 2>/dev/null || true

    # Fish
    local fish_comp_dir="$HOME/.config/fish/completions"
    if [[ -d "$HOME/.config/fish" ]]; then
        mkdir -p "$fish_comp_dir"
        "$TARGET" completions fish > "$fish_comp_dir/jr.fish" 2>/dev/null || true
    fi

    # Bash
    local bash_comp_dir="$HOME/.bash_completion.d"
    mkdir -p "$bash_comp_dir"
    "$TARGET" completions bash > "$bash_comp_dir/jr" 2>/dev/null || true

    print_success "$STR_COMPLETIONS_OK"
}

create_config() {
    print_step "$STR_CONFIG_CREATING"
    mkdir -p "$CONFIG_DIR"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
# jr configuration file (v3.0.0)
# Uncomment and modify to customize directories and editor

# sync_dir = "~/Documents/Journal"
# local_dir = "~/Documents/Journal_local"
# private_dir = "~/Documents/Journal_private"
# editor = "nvim" # or "code", "nano", "vim", etc.
# auto_sync = true
EOF
        print_success "$STR_CONFIG_OK"
    else
        print_info "Config already exists: $CONFIG_FILE"
    fi
}

verify_installation() {
    print_step "$STR_TESTING"
    if [[ -x "$TARGET" ]]; then
        local ver=$("$TARGET" --version 2>/dev/null || echo "unknown")
        print_success "$ver ($TARGET)"
    else
        print_error "$STR_INSTALL_FAIL"
        exit 1
    fi
}

print_summary() {
    echo ""
    echo -e "${BOLD}${GREEN}┌─────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${GREEN}│${NC}  ${GREEN}✓${NC} ${BOLD}$STR_DONE${NC}                     ${BOLD}${GREEN}│${NC}"
    echo -e "${BOLD}${GREEN}└─────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "  ${BOLD}Quick Start:${NC}"
    echo -e "    ${CYAN}jr \"Hello from v3! #first\"${NC}    Record entry"
    echo -e "    ${CYAN}jr view${NC}                       Read today's journal"
    echo -e "    ${CYAN}jr search \"keyword\"${NC}           Search journals"
    echo -e "    ${CYAN}jr stats${NC}                      View streak & stats"
    echo -e "    ${CYAN}jr status${NC}                     Check sync & repos"
    echo ""
}

main() {
    init_i18n
    print_banner
    install_binary
    configure_path
    install_completions
    create_config
    verify_installation
    print_summary
}

main "$@"
