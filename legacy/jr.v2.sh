#!/bin/bash

# ==========================================
# Journal CLI (jr) - v2.0.0
# ==========================================
# A minimalist terminal journal for developers
# Following Unix philosophy: do one thing and do it well

set -euo pipefail

# ==========================================
# Version & Constants
# ==========================================
readonly VERSION="2.0.0"
readonly PROG_NAME="jr"

# Exit codes (sysexits.h)
readonly EXIT_OK=0           # Success
readonly EXIT_USAGE=64       # Command line usage error
readonly EXIT_DATAERR=65     # Data format error
readonly EXIT_NOINPUT=66     # Cannot open input
readonly EXIT_NOUSER=67      # Addressee unknown
readonly EXIT_NOHOST=68      # Host name unknown
readonly EXIT_UNAVAILABLE=69 # Service unavailable
readonly EXIT_SOFTWARE=70    # Internal software error
readonly EXIT_OSERR=71       # System error
readonly EXIT_OSFILE=72      # Critical OS file missing
readonly EXIT_CANTCREAT=73   # Can't create output file
readonly EXIT_IOERR=74       # I/O error
readonly EXIT_TEMPFAIL=75    # Temp failure
readonly EXIT_PROTOCOL=76    # Remote error in protocol
readonly EXIT_NOPERM=77     # Permission denied
readonly EXIT_CONFIG=78     # Configuration error

# ==========================================
# Platform Detection
# ==========================================
detect_os() {
    local os=$(uname -s)
    case "$os" in
        Linux*)     echo "linux" ;;
        Darwin*)    echo "macos" ;;
        FreeBSD*)   echo "freebsd" ;;
        OpenBSD*)   echo "openbsd" ;;
        NetBSD*)    echo "netbsd" ;;
        DragonFly*) echo "dragonfly" ;;
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

readonly OS_TYPE=$(detect_os)
readonly IS_BSD=$([[ "$OS_TYPE" =~ (freebsd|openbsd|netbsd|dragonfly) ]] && echo true || echo false)
readonly IS_MACOS=$([[ "$OS_TYPE" == "macos" ]] && echo true || echo false)
readonly IS_LINUX=$([[ "$OS_TYPE" == "linux" ]] && echo true || echo false)

# Cross-platform sed -i
sed_inplace() {
    if $IS_MACOS || $IS_BSD; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# Cross-platform date
epoch_seconds() {
    date +%s
}

# Cross-platform readlink (BSD compatible)
realpath_compat() {
    local path="$1"
    if command -v realpath >/dev/null 2>&1; then
        realpath "$path"
    elif command -v readlink >/dev/null 2>&1 && readlink -f "$path" >/dev/null 2>&1; then
        readlink -f "$path"
    else
        # Fallback for BSD
        (cd "$(dirname "$path")" && echo "$(pwd)/$(basename "$path")")
    fi
}

# ==========================================
# Color & Output Control
# ==========================================
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" == "" ]]; then
    readonly BLUE='\033[0;34m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly RED='\033[0;31m'
    readonly CYAN='\033[0;36m'
    readonly BOLD='\033[1m'
    readonly NC='\033[0m'
else
    readonly BLUE=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly RED=''
    readonly CYAN=''
    readonly BOLD=''
    readonly NC=''
fi

# Output control
QUIET=false
VERBOSE=false

# ==========================================
# Configuration
# ==========================================
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/jr/config"
JRNL_SYNC="${JRNL_SYNC:-$HOME/Documents/Journal}"
JRNL_LOCAL="${JRNL_LOCAL:-$HOME/Documents/Journal_local}"
JRNL_PRIVATE="${JRNL_PRIVATE:-$HOME/Documents/Journal_private}"

# Load config file if exists
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs | sed 's/^["'\'']\(.*\)["'\'']$/\1/')
            case "$key" in
                sync_dir) JRNL_SYNC="$value" ;;
                local_dir) JRNL_LOCAL="$value" ;;
                private_dir) JRNL_PRIVATE="$value" ;;
            esac
        done < "$CONFIG_FILE"
    fi
}

# ==========================================
# Output Functions
# ==========================================
log_info() {
    $QUIET || echo -e "${BLUE}$*${NC}"
}

log_success() {
    $QUIET || echo -e "${GREEN}$*${NC}"
}

log_warn() {
    echo -e "${YELLOW}$*${NC}" >&2
}

log_error() {
    echo -e "${RED}$*${NC}" >&2
}

log_debug() {
    $VERBOSE && echo -e "${CYAN}[DEBUG] $*${NC}" >&2
    return 0
}

# ==========================================
# Language Detection & i18n
# ==========================================
detect_language() {
    [[ "${LANG:-}" =~ ^en ]] || \
    [[ "${LC_ALL:-}" =~ ^en ]] || \
    [[ "${LC_MESSAGES:-}" =~ ^en ]] && echo "en" || echo "zh"
}

LANG_CODE=$(detect_language)

init_i18n() {
    if [[ "$LANG_CODE" == "en" ]]; then
        STR_USAGE="Usage:"
        STR_MODE_DEFAULT="Record to sync + local backup, sync to cloud"
        STR_MODE_DEFAULT_OPT="Open today's log in sync directory"
        STR_MODE_LOCAL="Record to local backup only (also sync when online)"
        STR_MODE_LOCAL_OPT="Open today's log in local backup directory"
        STR_MODE_PRIVATE="Record to private zone (never sync)"
        STR_MODE_PRIVATE_OPT="Open today's log in private zone"
        STR_OPT_TITLE="Options:"
        STR_NOTE_HDR="Directories:"
        STR_ERR_LOCK="Error: Only one editor can be selected."
        STR_ERR_ARG="Error: Invalid argument"
        STR_SUCCESS="Saved to"
        STR_ZONE_SYNC="Sync + Local"
        STR_ZONE_LOCAL="Local Backup"
        STR_ZONE_PRIVATE="Private Zone"
        STR_HEALING="Sync directory anomaly detected, self-healing..."
        STR_INIT="Initialized"
        STR_PRIVATE_SUFFIX="_private"
        STR_LOG_HEADER="Journal"
        # GitHub login
        STR_GH_NOT_INSTALLED="GitHub CLI (gh) is not installed."
        STR_GH_INSTALL_HINT="Install: https://cli.github.com/"
        STR_GH_WELCOME="Welcome to jr! Cloud sync requires GitHub authorization."
        STR_GH_LOGIN_STEPS="Login steps:"
        STR_GH_STEP_1="  1. jr will open GitHub login page"
        STR_GH_STEP_2="  2. Enter the one-time code shown in terminal"
        STR_GH_STEP_3="  3. Authorize jr to access your GitHub account"
        STR_GH_LOGIN_START="Starting GitHub login..."
        STR_GH_LOGIN_SUCCESS="GitHub login successful!"
        STR_GH_LOGIN_FAIL="Login failed. Data will be saved locally only."
        STR_GH_SKIP_WARNING="Skipping login. Data will only be saved locally."
        STR_GH_RETRY_HINT="To login later, run: jr --login"
        STR_GH_SYNC_ENV="Syncing cloud environment..."
        STR_GH_NO_REPO="Creating private repository..."
        STR_GH_SELFHEAL_SUCCESS="Self-healing successful."
        STR_GH_SELFHEAL_FAIL="Self-healing failed."
        STR_GIT_CONFIG_WARN="git user.name/email not configured."
        STR_GIT_CONFIG_HINT="Run: git config --global user.name \"Name\" && git config --global user.email \"email\""
        STR_GIT_COMMIT_FAIL="git commit failed."
        STR_GIT_PUSH_FAIL="git push failed."
        # Status
        STR_STATUS_TITLE="jr Status"
        STR_STATUS_VERSION="Version"
        STR_STATUS_GH="GitHub CLI"
        STR_STATUS_GH_INSTALLED="Installed"
        STR_STATUS_GH_NOT_INSTALLED="Not installed"
        STR_STATUS_AUTH="Auth Status"
        STR_STATUS_AUTH_OK="Authenticated"
        STR_STATUS_AUTH_FAIL="Not authenticated"
        STR_STATUS_DIRS="Directories"
        STR_STATUS_SYNC="Sync"
        STR_STATUS_LOCAL="Local"
        STR_STATUS_PRIVATE="Private"
        # Editor errors
        STR_ERR_CODE_NOT_FOUND="VS Code (code) not found."
        STR_ERR_GNOME_NOT_FOUND="GNOME Text Editor or gedit not found."
        STR_ERR_KATE_NOT_FOUND="Kate not found."
        STR_ERR_MACOS_NOT_FOUND="'open' command not found (macOS only)."
        STR_ERR_RUNNING="Another instance of jr is running."
        # Other
        STR_EXAMPLE_TEXT="content"
        STR_PERIOD="."
        STR_OPT_LOGIN="Login to GitHub"
        STR_OPT_STATUS="Show status"
        STR_OPT_VERSION="Show version"
        STR_OPT_QUIET="Quiet mode"
        STR_OPT_VERBOSE="Verbose mode"
    else
        STR_USAGE="用法:"
        STR_MODE_DEFAULT="记录至同步区+本地备份，自动同步到云端"
        STR_MODE_DEFAULT_OPT="使用编辑器打开今日同步区日志"
        STR_MODE_LOCAL="仅记录至本地备份（有网时也会同步）"
        STR_MODE_LOCAL_OPT="使用编辑器打开今日本地备份日志"
        STR_MODE_PRIVATE="记录至隔离区（永远不同步）"
        STR_MODE_PRIVATE_OPT="使用编辑器打开今日隔离区日志"
        STR_OPT_TITLE="选项:"
        STR_NOTE_HDR="目录:"
        STR_ERR_LOCK="错误: 只能选择一个编辑器选项。"
        STR_ERR_ARG="错误: 无效参数"
        STR_SUCCESS="已保存至"
        STR_ZONE_SYNC="同步区 + 本地备份"
        STR_ZONE_LOCAL="本地备份"
        STR_ZONE_PRIVATE="隔离区"
        STR_HEALING="检测到同步目录异常，正在自愈..."
        STR_INIT="已初始化"
        STR_PRIVATE_SUFFIX="_private"
        STR_LOG_HEADER="日志"
        # GitHub login
        STR_GH_NOT_INSTALLED="未安装 GitHub CLI (gh)。"
        STR_GH_INSTALL_HINT="安装: https://cli.github.com/"
        STR_GH_WELCOME="欢迎使用 jr！云端同步需要 GitHub 授权。"
        STR_GH_LOGIN_STEPS="登录步骤："
        STR_GH_STEP_1="  1. jr 将打开 GitHub 登录页面"
        STR_GH_STEP_2="  2. 输入终端中显示的一次性验证码"
        STR_GH_STEP_3="  3. 授权 jr 访问你的 GitHub 账户"
        STR_GH_LOGIN_START="正在启动 GitHub 登录..."
        STR_GH_LOGIN_SUCCESS="GitHub 登录成功！"
        STR_GH_LOGIN_FAIL="登录失败，数据将仅保存在本地。"
        STR_GH_SKIP_WARNING="跳过登录，数据将仅保存在本地。"
        STR_GH_RETRY_HINT="稍后登录请运行: jr --login"
        STR_GH_SYNC_ENV="正在同步云端环境..."
        STR_GH_NO_REPO="正在创建私有仓库..."
        STR_GH_SELFHEAL_SUCCESS="自愈成功。"
        STR_GH_SELFHEAL_FAIL="自愈失败。"
        STR_GIT_CONFIG_WARN="未配置 git user.name/email。"
        STR_GIT_CONFIG_HINT="运行: git config --global user.name \"姓名\" && git config --global user.email \"邮箱\""
        STR_GIT_COMMIT_FAIL="git commit 失败。"
        STR_GIT_PUSH_FAIL="git push 失败。"
        # Status
        STR_STATUS_TITLE="jr 状态"
        STR_STATUS_VERSION="版本"
        STR_STATUS_GH="GitHub CLI"
        STR_STATUS_GH_INSTALLED="已安装"
        STR_STATUS_GH_NOT_INSTALLED="未安装"
        STR_STATUS_AUTH="认证状态"
        STR_STATUS_AUTH_OK="已认证"
        STR_STATUS_AUTH_FAIL="未认证"
        STR_STATUS_DIRS="目录"
        STR_STATUS_SYNC="同步区"
        STR_STATUS_LOCAL="本地备份"
        STR_STATUS_PRIVATE="隔离区"
        # Editor errors
        STR_ERR_CODE_NOT_FOUND="未找到 VS Code (code)。"
        STR_ERR_GNOME_NOT_FOUND="未找到 GNOME Text Editor 或 gedit。"
        STR_ERR_KATE_NOT_FOUND="未找到 Kate。"
        STR_ERR_MACOS_NOT_FOUND="未找到 'open' 命令（仅限 macOS）。"
        STR_ERR_RUNNING="另一个 jr 实例正在运行。"
        # Other
        STR_EXAMPLE_TEXT="内容"
        STR_PERIOD="。"
        STR_OPT_LOGIN="登录 GitHub"
        STR_OPT_STATUS="查看状态"
        STR_OPT_VERSION="查看版本"
        STR_OPT_QUIET="静默模式"
        STR_OPT_VERBOSE="调试模式"
    fi
}

# ==========================================
# Help & Version
# ==========================================
show_help() {
    cat << EOF
${BOLD}$PROG_NAME${NC} - Journal CLI v${VERSION}

$STR_USAGE
  $PROG_NAME "$STR_EXAMPLE_TEXT"           $STR_MODE_DEFAULT
  $PROG_NAME -l "$STR_EXAMPLE_TEXT"       $STR_MODE_LOCAL
  $PROG_NAME -p "$STR_EXAMPLE_TEXT"       $STR_MODE_PRIVATE
  $PROG_NAME -c                          $STR_MODE_DEFAULT_OPT

$STR_OPT_TITLE
  -l, --local             $STR_MODE_LOCAL
  -p, --private           $STR_MODE_PRIVATE
  -c, --code              Use Code OSS to open
  -g, --gnome             Use GNOME Text Editor / gedit
  -k, --kde               Use Kate to open
  -m, --macos             Use macOS TextEdit
  -e, --edit              Use \$EDITOR or system default
  -x, --xdg               Use xdg-open (Linux)
  --login                 $STR_OPT_LOGIN
  --status                $STR_OPT_STATUS
  -q, --quiet             $STR_OPT_QUIET
  -v, --verbose           $STR_OPT_VERBOSE
  -V, --version           $STR_OPT_VERSION
  -h, --help              Show this help

$STR_NOTE_HDR
  $STR_STATUS_SYNC:  $JRNL_SYNC
  $STR_STATUS_LOCAL:   $JRNL_LOCAL
  $STR_STATUS_PRIVATE: $JRNL_PRIVATE

${BOLD}Examples:${NC}
  echo "note" | $PROG_NAME              Read from stdin
  $PROG_NAME -q "note"                  Silent mode
  $PROG_NAME -p -c                      Edit private journal
  NO_COLOR=1 $PROG_NAME "note"          Disable colors

${BOLD}Config:${NC}
  $CONFIG_FILE

${BOLD}Exit Codes:${NC}
  0   Success
  64  Usage error
  65  Data error
  75  Temporary failure
  77  Permission denied
  78  Configuration error
EOF
}

show_version() {
    echo "$PROG_NAME $VERSION"
}

show_status() {
    echo -e "${BOLD}$STR_STATUS_TITLE${NC}"
    echo "─────────────────────────────────"
    echo -e "$STR_STATUS_VERSION: $VERSION"
    echo -e "Platform: $OS_TYPE ($(uname -r))"
    echo ""
    
    # GitHub CLI status
    if command -v gh >/dev/null 2>&1; then
        echo -e "$STR_STATUS_GH: ${GREEN}$STR_STATUS_GH_INSTALLED${NC} ($(gh --version | head -1))"
        if gh auth status >/dev/null 2>&1; then
            echo -e "$STR_STATUS_AUTH: ${GREEN}$STR_STATUS_AUTH_OK${NC}"
        else
            echo -e "$STR_STATUS_AUTH: ${RED}$STR_STATUS_AUTH_FAIL${NC}"
        fi
    else
        echo -e "$STR_STATUS_GH: ${RED}$STR_STATUS_GH_NOT_INSTALLED${NC}"
    fi
    echo ""
    
    # Directory status
    echo -e "$STR_STATUS_DIRS:"
    for dir_info in "$JRNL_SYNC:$STR_STATUS_SYNC" "$JRNL_LOCAL:$STR_STATUS_LOCAL" "$JRNL_PRIVATE:$STR_STATUS_PRIVATE"; do
        IFS=':' read -r dir label <<< "$dir_info"
        if [[ -d "$dir" ]]; then
            count=$(find "$dir" -name "*.md" -type f 2>/dev/null | wc -l)
            echo -e "  $label: ${GREEN}✓${NC} $dir ($count files)"
        else
            echo -e "  $label: ${YELLOW}○${NC} $dir (not created)"
        fi
    done
}

# ==========================================
# Concurrency Lock
# ==========================================
LOCKFILE="/tmp/jr.lock"

acquire_lock() {
    # Cross-platform lock
    # Priority: flock (Linux) > shlock (BSD) > mkdir (fallback)
    
    if command -v flock >/dev/null 2>&1; then
        # Linux: use flock
        exec 200>"$LOCKFILE"
        if ! flock -n 200; then
            log_error "$STR_ERR_RUNNING"
            exit $EXIT_TEMPFAIL
        fi
    elif command -v shlock >/dev/null 2>&1; then
        # BSD: use shlock
        if ! shlock -f "$LOCKFILE" -d $$; then
            log_error "$STR_ERR_RUNNING"
            exit $EXIT_TEMPFAIL
        fi
        trap 'rm -f "$LOCKFILE"' EXIT
    else
        # Fallback: atomic mkdir
        if ! mkdir "$LOCKFILE" 2>/dev/null; then
            # Check if stale lock (older than 5 minutes)
            if [[ -d "$LOCKFILE" ]]; then
                local lock_age
                if $IS_BSD || $IS_MACOS; then
                    # BSD/macOS: use stat
                    lock_age=$(( $(date +%s) - $(stat -f %m "$LOCKFILE" 2>/dev/null || echo 0) ))
                else
                    # Linux: use find
                    lock_age=$(find "$LOCKFILE" -maxdepth 0 -mmin +5 2>/dev/null | wc -l)
                fi
                if [[ "$lock_age" -gt 300 ]] || [[ "$lock_age" -gt 0 ]]; then
                    rm -rf "$LOCKFILE"
                    mkdir "$LOCKFILE" 2>/dev/null || {
                        log_error "$STR_ERR_RUNNING"
                        exit $EXIT_TEMPFAIL
                    }
                else
                    log_error "$STR_ERR_RUNNING"
                    exit $EXIT_TEMPFAIL
                fi
            else
                log_error "$STR_ERR_RUNNING"
                exit $EXIT_TEMPFAIL
            fi
        fi
        trap 'rm -rf "$LOCKFILE"' EXIT
    fi
}

# ==========================================
# GitHub Operations
# ==========================================
check_gh_installed() {
    if ! command -v gh >/dev/null 2>&1; then
        log_warn "$STR_GH_NOT_INSTALLED"
        log_info "$STR_GH_INSTALL_HINT"
        return 1
    fi
    return 0
}

check_gh_auth() {
    gh auth status >/dev/null 2>&1
}

prompt_login() {
    log_info "$STR_GH_WELCOME"
    echo "$STR_GH_LOGIN_STEPS"
    echo "$STR_GH_STEP_1"
    echo "$STR_GH_STEP_2"
    echo "$STR_GH_STEP_3"
    echo ""
    read -p "$(echo -e "${BOLD}>>>${NC} ")" -r response
    [[ "$response" =~ ^[Yy] ]]
}

do_login() {
    if ! check_gh_installed; then
        exit $EXIT_UNAVAILABLE
    fi
    
    log_info "$STR_GH_LOGIN_START"
    if gh auth login; then
        log_success "$STR_GH_LOGIN_SUCCESS"
        return 0
    else
        log_error "$STR_GH_LOGIN_FAIL"
        return 1
    fi
}

init_sync_repo() {
    if [ -d "$JRNL_SYNC" ] && [ ! -d "$JRNL_SYNC/.git" ]; then
        log_warn "$STR_HEALING"
        local tmp_recovery="${JRNL_SYNC}_recovery_$(date +%s)"
        mv "$JRNL_SYNC" "$tmp_recovery"
        
        if gh repo clone Journal "$JRNL_SYNC" >/dev/null 2>&1; then
            find "$tmp_recovery" -name "*.md" -type f | while read -r backup_file; do
                local relative="${backup_file#$tmp_recovery/}"
                local target="$JRNL_SYNC/$relative"
                mkdir -p "$(dirname "$target")"
                if [ -f "$target" ]; then
                    echo -e "\n--- [Recovered $(date +'%Y-%m-%d %H:%M:%S')] ---\n" >> "$target"
                    cat "$backup_file" >> "$target"
                else
                    cp "$backup_file" "$target"
                fi
            done
            rm -rf "$tmp_recovery"
            log_success "$STR_GH_SELFHEAL_SUCCESS"
        else
            mv "$tmp_recovery" "$JRNL_SYNC"
            log_error "$STR_GH_SELFHEAL_FAIL"
            return 1
        fi
    elif [ ! -d "$JRNL_SYNC" ]; then
        log_info "$STR_GH_SYNC_ENV"
        if gh repo view Journal >/dev/null 2>&1; then
            gh repo clone Journal "$JRNL_SYNC" >/dev/null 2>&1
        else
            log_info "$STR_GH_NO_REPO"
            mkdir -p "$JRNL_SYNC"
            (
                cd "$JRNL_SYNC" || exit 1
                git init -b main
                git commit --allow-empty -m "Initial commit"
                gh repo create Journal --private --source=. --remote=origin --push
            ) >/dev/null 2>&1
        fi
    fi
}

git_sync() {
    local repo_dir="$1"
    (
        cd "$repo_dir" || exit 1
        
        if ! git config user.name >/dev/null 2>&1 || ! git config user.email >/dev/null 2>&1; then
            log_warn "$STR_GIT_CONFIG_WARN"
            log_info "$STR_GIT_CONFIG_HINT"
            exit 0
        fi
        
        git add -A
        if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
            local branch=$(git branch --show-current 2>/dev/null || echo "main")
            [[ -z "$branch" ]] && branch="main"
            
            if ! git commit -m "jr: $(date +'%Y-%m-%d %H:%M:%S')" --quiet; then
                log_error "$STR_GIT_COMMIT_FAIL"
                exit $EXIT_SOFTWARE
            fi
            
            if ! git pull origin "$branch" --rebase --quiet 2>/dev/null; then
                if ! git push -u origin "$branch" --quiet 2>/dev/null; then
                    log_error "$STR_GIT_PUSH_FAIL"
                    exit $EXIT_TEMPFAIL
                fi
            else
                if ! git push -u origin "$branch" --quiet 2>/dev/null; then
                    log_error "$STR_GIT_PUSH_FAIL"
                    exit $EXIT_TEMPFAIL
                fi
            fi
        fi
    )
}

# ==========================================
# File Operations
# ==========================================
get_date_parts() {
    YEAR=$(date +'%Y')
    MONTH=$(date +'%m')
    CURRENT_DATE=$(date +'%Y-%m-%d')
    CURRENT_TIME=$(date +'%H:%M:%S')
}

init_journal_file() {
    local base_dir="$1"
    local suffix="$2"
    local target_dir="${base_dir}/${YEAR}/${MONTH}"
    local file_name="${target_dir}/${CURRENT_DATE}${suffix}.md"
    
    mkdir -p "$target_dir"
    if [ ! -f "$file_name" ]; then
        echo -e "# $CURRENT_DATE $STR_LOG_HEADER\n" > "$file_name"
        log_debug "$STR_INIT: $file_name"
    fi
    echo "$file_name"
}

write_content() {
    local file="$1"
    local content="$2"
    echo -e "## $CURRENT_TIME\n$content\n" >> "$file"
}

# ==========================================
# Editor Support
# ==========================================
open_editor() {
    local file="$1"
    local editor="$2"
    
    case "$editor" in
        -c|--code)
            if command -v code >/dev/null 2>&1; then
                code --wait "$file"
            else
                log_error "$STR_ERR_CODE_NOT_FOUND"
                return $EXIT_UNAVAILABLE
            fi
            ;;
        -g|--gnome)
            local g_cmd=$(command -v gnome-text-editor || command -v gedit || true)
            if [[ -n "$g_cmd" ]]; then
                "$g_cmd" "$file" &
                wait
            else
                log_error "$STR_ERR_GNOME_NOT_FOUND"
                return $EXIT_UNAVAILABLE
            fi
            ;;
        -k|--kde)
            if command -v kate >/dev/null 2>&1; then
                kate --new --block "$file"
            else
                log_error "$STR_ERR_KATE_NOT_FOUND"
                return $EXIT_UNAVAILABLE
            fi
            ;;
        -m|--macos)
            if command -v open >/dev/null 2>&1; then
                open -W -t "$file"
            else
                log_error "$STR_ERR_MACOS_NOT_FOUND"
                return $EXIT_UNAVAILABLE
            fi
            ;;
        -e|--edit)
            # Cross-platform default editor
            local editor_cmd="${EDITOR:-}"
            if [[ -z "$editor_cmd" ]]; then
                if [[ "$(uname)" == "Darwin" ]]; then
                    editor_cmd="open -t"
                elif command -v xdg-open >/dev/null 2>&1; then
                    editor_cmd="xdg-open"
                else
                    editor_cmd="vi"
                fi
            fi
            $editor_cmd "$file"
            ;;
        -x|--xdg)
            # Use xdg-open (Linux)
            if command -v xdg-open >/dev/null 2>&1; then
                xdg-open "$file"
            else
                log_error "xdg-open not found (Linux only)."
                return $EXIT_UNAVAILABLE
            fi
            ;;
    esac
}

# ==========================================
# Main Logic
# ==========================================
main() {
    # Load configuration
    load_config
    
    # Initialize i18n
    init_i18n
    
    # Parse arguments
    local is_local=false
    local is_private=false
    local is_login=false
    local is_status=false
    local editor=""
    local text_content=""
    
    # First pass: check for special actions
    for arg in "$@"; do
        case "$arg" in
            -h|--help) show_help; exit $EXIT_OK ;;
            -V|--version) show_version; exit $EXIT_OK ;;
            --status) is_status=true ;;
            --login) is_login=true ;;
        esac
    done
    
    # Handle --status
    if $is_status; then
        show_status
        exit $EXIT_OK
    fi
    
    # Handle --login
    if $is_login; then
        do_login
        exit $EXIT_OK
    fi
    
    # Acquire lock
    acquire_lock
    
    # Second pass: parse all arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help|-V|--version|--status|--login)
                shift ;;
            -l|--local)
                is_local=true; shift ;;
            -p|--private)
                is_private=true; shift ;;
            -c|--code|-g|--gnome|-k|--kde|-m|--macos|-e|--edit|-x|--xdg)
                if [[ -n "$editor" ]]; then
                    log_error "$STR_ERR_LOCK"
                    exit $EXIT_USAGE
                fi
                editor="$1"; shift ;;
            -q|--quiet)
                QUIET=true; shift ;;
            -v|--verbose)
                VERBOSE=true; shift ;;
            -*)
                log_error "$STR_ERR_ARG: $1"
                exit $EXIT_USAGE ;;
            *)
                text_content="$*"; break ;;
        esac
    done
    
    # Validate combinations
    if $is_local && $is_private; then
        log_error "Error: -l and -p are mutually exclusive."
        exit $EXIT_USAGE
    fi
    
    # Check for stdin input
    if [[ -z "$text_content" ]] && [[ -n "$editor" || ! -t 0 ]]; then
        if [[ ! -t 0 ]]; then
            text_content=$(cat)
        fi
    fi
    
    # Determine write mode
    local write_sync=false
    local write_local=false
    local write_private=false
    
    if $is_private; then
        write_private=true
    elif $is_local; then
        write_local=true
    else
        write_sync=true
        write_local=true
    fi
    
    # GitHub authentication (only for sync mode)
    if $write_sync; then
        if ! check_gh_installed; then
            log_warn "$STR_GH_SKIP_WARNING"
            write_sync=false
        elif ! check_gh_auth; then
            if prompt_login; then
                if ! do_login; then
                    write_sync=false
                fi
            else
                log_warn "$STR_GH_SKIP_WARNING"
                log_info "$STR_GH_RETRY_HINT"
                write_sync=false
            fi
        fi
    fi
    
    # Initialize sync repo
    if $write_sync; then
        init_sync_repo || write_sync=false
    fi
    
    # Create directories
    $write_local && mkdir -p "$JRNL_LOCAL"
    $write_private && mkdir -p "$JRNL_PRIVATE"
    
    # Get date parts
    get_date_parts
    
    # Initialize files
    local file_sync=""
    local file_local=""
    local file_private=""
    
    $write_sync && file_sync=$(init_journal_file "$JRNL_SYNC" "")
    $write_local && file_local=$(init_journal_file "$JRNL_LOCAL" "_local")
    $write_private && file_private=$(init_journal_file "$JRNL_PRIVATE" "$STR_PRIVATE_SUFFIX")
    
    # Determine edit file
    local edit_file=""
    [[ -n "$file_sync" ]] && edit_file="$file_sync"
    [[ -n "$file_local" ]] && edit_file="$file_local"
    [[ -n "$file_private" ]] && edit_file="$file_private"
    
    # Execute action
    if [[ -n "$editor" ]]; then
        open_editor "$edit_file" "$editor"
    elif [[ -n "$text_content" ]]; then
        [[ -n "$file_sync" ]] && write_content "$file_sync" "$text_content"
        [[ -n "$file_local" ]] && write_content "$file_local" "$text_content"
        [[ -n "$file_private" ]] && write_content "$file_private" "$text_content"
        
        if $write_sync; then
            log_success "$STR_SUCCESS $STR_ZONE_SYNC$STR_PERIOD"
        elif $write_local; then
            log_success "$STR_SUCCESS $STR_ZONE_LOCAL$STR_PERIOD"
        elif $write_private; then
            log_success "$STR_SUCCESS $STR_ZONE_PRIVATE$STR_PERIOD"
        fi
    fi
    
    # Git sync
    if $write_sync && [[ -n "$file_sync" ]]; then
        git_sync "$JRNL_SYNC"
    fi
    if $write_local && [[ -n "$file_local" ]] && [[ -d "$JRNL_LOCAL/.git" ]]; then
        git_sync "$JRNL_LOCAL"
    fi
    
    exit $EXIT_OK
}

# Run main
main "$@"
