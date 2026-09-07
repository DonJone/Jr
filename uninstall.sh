#!/bin/bash

# ==========================================
# jr - Journal CLI Uninstaller v3.0.0
# ==========================================

set -euo pipefail

# ==========================================
# Constants
# ==========================================
readonly VERSION="3.0.0"
readonly BIN_DIR="$HOME/.local/bin"
readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/jr"
readonly TARGET="$BIN_DIR/jr"

# ==========================================
# Color & Output
# ==========================================
if [[ -t 1 ]]; then
    readonly BLUE='\033[0;34m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly RED='\033[0;31m'
    readonly BOLD='\033[1m'
    readonly DIM='\033[2m'
    readonly NC='\033[0m'
else
    readonly BLUE=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly RED=''
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
        STR_WELCOME="jr - Journal CLI Uninstaller"
        STR_CONFIRM="This will remove jr from your system."
        STR_CONFIRM_PROMPT="Continue? (y/n)"
        STR_REMOVING="Removing jr..."
        STR_REM_BIN="Removing binary"
        STR_REM_CONFIG="Removing configuration"
        STR_REM_COMPLETIONS="Removing shell completions"
        STR_REM_PATH="Removing PATH configuration"
        STR_DATA_SAFE="Your journal data in ~/Documents/ is preserved."
        STR_DONE="Uninstall complete!"
        STR_CANCELLED="Uninstall cancelled."
        STR_NOT_INSTALLED="jr is not installed."
    else
        STR_WELCOME="jr - 终端日志工具卸载程序"
        STR_CONFIRM="此操作将从系统中移除 jr。"
        STR_CONFIRM_PROMPT="是否继续？(y/n)"
        STR_REMOVING="正在卸载 jr..."
        STR_REM_BIN="移除主程序"
        STR_REM_CONFIG="移除配置文件"
        STR_REM_COMPLETIONS="移除 Shell 补全脚本"
        STR_REM_PATH="移除 PATH 配置"
        STR_DATA_SAFE="~/Documents/ 中的日志数据已保留。"
        STR_DONE="卸载完成！"
        STR_CANCELLED="卸载已取消。"
        STR_NOT_INSTALLED="jr 未安装。"
    fi
}

print_banner() {
    echo ""
    echo -e "${BOLD}${BLUE}┌─────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${BLUE}│${NC}  ${BOLD}jr${NC} - Journal CLI Uninstaller ${DIM}v${VERSION}${NC}  ${BOLD}${BLUE}│${NC}"
    echo -e "${BOLD}${BLUE}└─────────────────────────────────────────┘${NC}"
    echo ""
}

print_step() { echo -e "  ${BLUE}▸${NC} $*"; }
print_success() { echo -e "  ${GREEN}✓${NC} $*"; }
print_warn() { echo -e "  ${YELLOW}!${NC} $*"; }
print_info() { echo -e "  ${DIM}$*${NC}"; }

detect_rc() {
    local current_shell=$(basename "$SHELL")
    case "$current_shell" in
        zsh)  echo "$HOME/.zshrc" ;;
        bash) echo "$HOME/.bashrc" ;;
        *)    echo "$HOME/.profile" ;;
    esac
}

main() {
    init_i18n
    print_banner

    if [[ ! -f "$TARGET" ]]; then
        print_warn "$STR_NOT_INSTALLED"
        exit 0
    fi

    echo -e "  $STR_CONFIRM"
    echo -e "  ${DIM}$STR_DATA_SAFE${NC}"
    echo ""
    read -p "  $STR_CONFIRM_PROMPT: " -r response

    if [[ ! "$response" =~ ^[Yy] ]]; then
        echo ""
        print_info "$STR_CANCELLED"
        exit 0
    fi

    echo ""
    print_step "$STR_REMOVING"

    # Remove binary
    if [[ -f "$TARGET" ]]; then
        rm -f "$TARGET"
        print_success "$STR_REM_BIN: $TARGET"
    fi

    # Remove config
    if [[ -d "$CONFIG_DIR" ]]; then
        rm -rf "$CONFIG_DIR"
        print_success "$STR_REM_CONFIG: $CONFIG_DIR"
    fi

    # Remove completions
    rm -f "$HOME/.zsh/completions/_jr" 2>/dev/null || true
    rm -f "$HOME/.bash_completion.d/jr" 2>/dev/null || true
    rm -f "$HOME/.config/fish/completions/jr.fish" 2>/dev/null || true
    print_success "$STR_REM_COMPLETIONS"

    # Remove PATH configuration
    local rc_file=$(detect_rc)
    if [[ -f "$rc_file" ]] && grep -q "# jr CLI path" "$rc_file" 2>/dev/null; then
        local os_type=$(uname -s)
        case "$os_type" in
            Darwin|*BSD*)
                sed -i '' '/# jr CLI path/,+1d' "$rc_file"
                ;;
            *)
                sed -i '/# jr CLI path/,+1d' "$rc_file"
                ;;
        esac
        print_success "$STR_REM_PATH: $rc_file"
    fi

    # Summary
    echo ""
    echo -e "${BOLD}${GREEN}┌─────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${GREEN}│${NC}  ${GREEN}✓${NC} ${BOLD}$STR_DONE${NC}                       ${BOLD}${GREEN}│${NC}"
    echo -e "${BOLD}${GREEN}└─────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "  ${DIM}$STR_DATA_SAFE${NC}"
    echo ""
}

main "$@"
