#!/bin/bash

# ==========================================
# jr - Journal CLI Installer v2.0.0
# ==========================================
# One-click installation script for jr
# https://github.com/DonJone/jr

set -euo pipefail

# ==========================================
# Constants
# ==========================================
readonly VERSION="2.0.0"
readonly REPO_URL="https://raw.githubusercontent.com/DonJone/jr/main"
readonly GITHUB_URL="https://github.com/DonJone/jr"
readonly BIN_DIR="$HOME/.local/bin"
readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/jr"
readonly CONFIG_FILE="$CONFIG_DIR/config"
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
        STR_WELCOME="Welcome to jr - Journal CLI Installer"
        STR_VERSION="Version"
        STR_CHECKING="Checking system requirements..."
        STR_DEPS_OK="All dependencies satisfied"
        STR_DEPS_MISSING="Missing dependencies:"
        STR_GH_NOT_FOUND="GitHub CLI (gh) not found"
        STR_GH_INSTALL_PROMPT="Install gh now? (y/n/s to skip)"
        STR_GH_INSTALLING="Installing GitHub CLI..."
        STR_GH_INSTALL_OK="GitHub CLI installed successfully"
        STR_GH_INSTALL_SKIP="Skipping gh installation. Cloud sync will be disabled."
        STR_GH_AUTH_PROMPT="Login to GitHub for cloud sync? (y/n)"
        STR_GH_AUTH_START="Starting GitHub login..."
        STR_GH_AUTH_OK="GitHub login successful"
        STR_GH_AUTH_SKIP="Skipping login. You can run 'jr --login' later."
        STR_INSTALLING="Installing jr..."
        STR_INSTALL_OK="jr installed successfully"
        STR_INSTALL_FAIL="Installation failed"
        STR_PATH_CONFIG="Configuring PATH..."
        STR_PATH_OK="PATH configured"
        STR_PATH_EXISTS="PATH already configured"
        STR_CONFIG_CREATING="Creating configuration file..."
        STR_CONFIG_OK="Configuration file created"
        STR_TESTING="Running installation test..."
        STR_TEST_OK="Installation test passed"
        STR_TEST_FAIL="Installation test failed"
        STR_DONE="Installation complete!"
        STR_USAGE_HINT="Run 'jr --help' to get started"
        STR_UNINSTALL_HINT="To uninstall: bash <(curl -fsSL $REPO_URL/uninstall.sh)"
        STR_NEXT_STEPS="Next steps:"
        STR_SOURCE_RC="Run this to apply changes:"
        STR_ALREADY_INSTALLED="jr is already installed. Upgrade? (y/n)"
        STR_UPGRADE_OK="jr upgraded successfully"
        STR_CREATING_DIR="Creating directory..."
    else
        STR_WELCOME="欢迎安装 jr - 终端日志工具"
        STR_VERSION="版本"
        STR_CHECKING="正在检查系统要求..."
        STR_DEPS_OK="所有依赖已满足"
        STR_DEPS_MISSING="缺少依赖："
        STR_GH_NOT_FOUND="未找到 GitHub CLI (gh)"
        STR_GH_INSTALL_PROMPT="是否安装 gh？(y/n/s 跳过)"
        STR_GH_INSTALLING="正在安装 GitHub CLI..."
        STR_GH_INSTALL_OK="GitHub CLI 安装成功"
        STR_GH_INSTALL_SKIP="跳过 gh 安装，云端同步将不可用。"
        STR_GH_AUTH_PROMPT="是否登录 GitHub 以启用云端同步？(y/n)"
        STR_GH_AUTH_START="正在启动 GitHub 登录..."
        STR_GH_AUTH_OK="GitHub 登录成功"
        STR_GH_AUTH_SKIP="跳过登录。稍后可运行 'jr --login'。"
        STR_INSTALLING="正在安装 jr..."
        STR_INSTALL_OK="jr 安装成功"
        STR_INSTALL_FAIL="安装失败"
        STR_PATH_CONFIG="正在配置 PATH..."
        STR_PATH_OK="PATH 已配置"
        STR_PATH_EXISTS="PATH 已存在"
        STR_CONFIG_CREATING="正在创建配置文件..."
        STR_CONFIG_OK="配置文件已创建"
        STR_TESTING="正在运行安装测试..."
        STR_TEST_OK="安装测试通过"
        STR_TEST_FAIL="安装测试失败"
        STR_DONE="安装完成！"
        STR_USAGE_HINT="运行 'jr --help' 开始使用"
        STR_UNINSTALL_HINT="卸载命令：bash <(curl -fsSL $REPO_URL/uninstall.sh)"
        STR_NEXT_STEPS="后续步骤："
        STR_SOURCE_RC="运行以下命令使配置生效："
        STR_ALREADY_INSTALLED="jr 已安装。是否升级？(y/n)"
        STR_UPGRADE_OK="jr 升级成功"
        STR_CREATING_DIR="正在创建目录..."
    fi
}

# ==========================================
# Output Functions
# ==========================================
print_banner() {
    echo ""
    echo -e "${BOLD}${BLUE}┌─────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${BLUE}│${NC}  ${BOLD}jr${NC} - Journal CLI ${DIM}v${VERSION}${NC}               ${BOLD}${BLUE}│${NC}"
    echo -e "${BOLD}${BLUE}│${NC}  ${DIM}A minimalist journal for developers${NC}   ${BOLD}${BLUE}│${NC}"
    echo -e "${BOLD}${BLUE}└─────────────────────────────────────────┘${NC}"
    echo ""
}

print_step() {
    echo -e "  ${BLUE}▸${NC} $*"
}

print_success() {
    echo -e "  ${GREEN}✓${NC} $*"
}

print_warn() {
    echo -e "  ${YELLOW}!${NC} $*"
}

print_error() {
    echo -e "  ${RED}✗${NC} $*"
}

print_info() {
    echo -e "  ${DIM}$*${NC}"
}

# ==========================================
# Dependency Check
# ==========================================
check_dependencies() {
    print_step "$STR_CHECKING"
    
    local missing=()
    local has_git=false
    local has_curl=false
    local has_gh=false
    
    if command -v git >/dev/null 2>&1; then
        print_success "git $(git --version | awk '{print $3}')"
        has_git=true
    else
        missing+=("git")
        print_error "git"
    fi
    
    if command -v curl >/dev/null 2>&1; then
        print_success "curl $(curl --version | head -1 | awk '{print $2}')"
        has_curl=true
    else
        missing+=("curl")
        print_error "curl"
    fi
    
    if command -v gh >/dev/null 2>&1; then
        print_success "gh $(gh --version | head -1 | awk '{print $3}')"
        has_gh=true
    else
        print_warn "$STR_GH_NOT_FOUND"
    fi
    
    echo ""
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "$STR_DEPS_MISSING ${missing[*]}"
        echo ""
        echo -e "  ${DIM}Please install missing dependencies and try again.${NC}"
        exit 1
    fi
    
    # Return gh status
    $has_gh && echo "has_gh" || echo "no_gh"
}

# ==========================================
# GitHub CLI Installation
# ==========================================
install_gh_interactive() {
    echo ""
    print_step "$STR_GH_NOT_FOUND"
    echo ""
    echo -e "  ${DIM}gh is required for cloud sync features.${NC}"
    echo -e "  ${DIM}Install guide: https://cli.github.com/${NC}"
    echo ""
    
    read -p "  $STR_GH_INSTALL_PROMPT: " -r response
    case "$response" in
        y|Y|yes|YES)
            print_step "$STR_GH_INSTALLING"
            
            if [[ "$(uname)" == "Darwin" ]]; then
                if command -v brew >/dev/null 2>&1; then
                    brew install gh && print_success "$STR_GH_INSTALL_OK" && return 0
                else
                    print_error "Homebrew not found. Install from https://brew.sh"
                fi
            elif [[ -f /etc/debian_version ]]; then
                print_info "sudo apt install gh"
                sudo apt update && sudo apt install -y gh && print_success "$STR_GH_INSTALL_OK" && return 0
            elif [[ -f /etc/fedora-release ]]; then
                print_info "sudo dnf install gh"
                sudo dnf install -y gh && print_success "$STR_GH_INSTALL_OK" && return 0
            elif [[ -f /etc/arch-release ]]; then
                print_info "sudo pacman -S github-cli"
                sudo pacman -S --noconfirm github-cli && print_success "$STR_GH_INSTALL_OK" && return 0
            fi
            
            print_error "$STR_INSTALL_FAIL"
            return 1
            ;;
        s|S|skip|SKIP)
            print_warn "$STR_GH_INSTALL_SKIP"
            return 1
            ;;
        *)
            print_warn "$STR_GH_INSTALL_SKIP"
            return 1
            ;;
    esac
}

# ==========================================
# GitHub Authentication
# ==========================================
setup_github_auth() {
    echo ""
    print_step "$STR_GH_AUTH_PROMPT"
    read -p "  " -r response
    
    case "$response" in
        y|Y|yes|YES)
            print_step "$STR_GH_AUTH_START"
            if gh auth login; then
                print_success "$STR_GH_AUTH_OK"
                return 0
            else
                print_warn "$STR_GH_AUTH_SKIP"
                return 1
            fi
            ;;
        *)
            print_warn "$STR_GH_AUTH_SKIP"
            return 1
            ;;
    esac
}

# ==========================================
# Installation
# ==========================================
install_jr() {
    print_step "$STR_INSTALLING"
    
    # Create bin directory
    mkdir -p "$BIN_DIR"
    
    # Download jr
    if curl -fsSL "$REPO_URL/jr" -o "$TARGET" 2>/dev/null; then
        chmod +x "$TARGET"
        print_success "$STR_INSTALL_OK"
        return 0
    else
        # Fallback: try to copy from current directory
        if [[ -f "$(dirname "$0")/jr" ]]; then
            cp "$(dirname "$0")/jr" "$TARGET"
            chmod +x "$TARGET"
            print_success "$STR_INSTALL_OK"
            return 0
        fi
        print_error "$STR_INSTALL_FAIL"
        return 1
    fi
}

# ==========================================
# PATH Configuration
# ==========================================
configure_path() {
    print_step "$STR_PATH_CONFIG"
    
    # Check if already in PATH
    if [[ ":$PATH:" == *":$BIN_DIR:"* ]]; then
        print_success "$STR_PATH_EXISTS"
        return 0
    fi
    
    # Detect shell and RC file
    local current_shell=$(basename "$SHELL")
    local rc_file=""
    
    case "$current_shell" in
        zsh)  rc_file="$HOME/.zshrc" ;;
        bash) rc_file="$HOME/.bashrc" ;;
        *)    rc_file="$HOME/.profile" ;;
    esac
    
    # Check if already configured
    if grep -q "\.local/bin" "$rc_file" 2>/dev/null; then
        print_success "$STR_PATH_EXISTS"
        return 0
    fi
    
    # Add to PATH
    echo "" >> "$rc_file"
    echo "# jr CLI path" >> "$rc_file"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc_file"
    
    print_success "$STR_PATH_OK ($rc_file)"
    echo ""
    echo -e "  ${BOLD}$STR_SOURCE_RC${NC}"
    echo -e "  ${CYAN}source $rc_file${NC}"
    
    return 0
}

# ==========================================
# Configuration File
# ==========================================
create_config() {
    print_step "$STR_CONFIG_CREATING"
    
    mkdir -p "$CONFIG_DIR"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
# jr configuration file
# Uncomment and modify to customize paths

# sync_dir="$HOME/Documents/Journal"
# local_dir="$HOME/Documents/Journal_local"
# private_dir="$HOME/Documents/Journal_private"
EOF
        print_success "$STR_CONFIG_OK ($CONFIG_FILE)"
    else
        print_info "Config already exists: $CONFIG_FILE"
    fi
}

# ==========================================
# Installation Test
# ==========================================
run_test() {
    print_step "$STR_TESTING"
    
    # Test if jr is executable
    if [[ -x "$TARGET" ]]; then
        local version=$("$TARGET" --version 2>/dev/null || echo "unknown")
        print_success "jr $version"
    else
        print_error "$STR_TEST_FAIL"
        return 1
    fi
    
    # Test basic functionality
    local test_dir=$(mktemp -d)
    HOME="$test_dir" "$TARGET" -p -q "test" >/dev/null 2>&1
    
    if [[ -f "$test_dir/Documents/Journal_private/"*"_private.md" ]] 2>/dev/null; then
        print_success "$STR_TEST_OK"
    else
        print_warn "Test file not created (non-critical)"
    fi
    
    rm -rf "$test_dir"
    return 0
}

# ==========================================
# Post-Install Summary
# ==========================================
print_summary() {
    echo ""
    echo -e "${BOLD}${GREEN}┌─────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${GREEN}│${NC}  ${GREEN}✓${NC} ${BOLD}$STR_DONE${NC}                     ${BOLD}${GREEN}│${NC}"
    echo -e "${BOLD}${GREEN}└─────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "  ${BOLD}$STR_NEXT_STEPS${NC}"
    echo ""
    echo -e "  ${DIM}1.${NC} $STR_USAGE_HINT"
    echo -e "     ${CYAN}jr --help${NC}"
    echo ""
    echo -e "  ${DIM}2.${NC} Record your first journal"
    echo -e "     ${CYAN}jr \"Hello, jr!\"${NC}"
    echo ""
    echo -e "  ${DIM}3.${NC} Login to GitHub for cloud sync"
    echo -e "     ${CYAN}jr --login${NC}"
    echo ""
    echo -e "  ${BOLD}Directories:${NC}"
    echo -e "  ${DIM}Sync:${NC}    ~/Documents/Journal"
    echo -e "  ${DIM}Local:${NC}   ~/Documents/Journal_local"
    echo -e "  ${DIM}Private:${NC} ~/Documents/Journal_private"
    echo ""
    echo -e "  ${DIM}$STR_UNINSTALL_HINT${NC}"
    echo ""
}

# ==========================================
# Main
# ==========================================
main() {
    init_i18n
    print_banner
    
    # Check if already installed
    if [[ -x "$TARGET" ]]; then
        local current_version=$("$TARGET" --version 2>/dev/null || echo "unknown")
        echo -e "  ${YELLOW}$STR_ALREADY_INSTALLED${NC} ${DIM}($current_version)${NC}"
        read -p "  " -r response
        if [[ ! "$response" =~ ^[Yy] ]]; then
            echo -e "  ${DIM}Installation cancelled.${NC}"
            exit 0
        fi
    fi
    
    # Check dependencies
    local gh_status=$(check_dependencies)
    
    # Install gh if needed
    if [[ "$gh_status" == "no_gh" ]]; then
        install_gh_interactive || true
    fi
    
    # Install jr
    echo ""
    install_jr || exit 1
    
    # Configure PATH
    echo ""
    configure_path
    
    # Create config file
    echo ""
    create_config
    
    # Setup GitHub auth
    if command -v gh >/dev/null 2>&1; then
        if ! gh auth status >/dev/null 2>&1; then
            setup_github_auth || true
        fi
    fi
    
    # Run test
    echo ""
    run_test || true
    
    # Print summary
    print_summary
}

main "$@"
