#!/bin/bash

# ==========================================
# jr 日志工具 - 卸载脚本
# ==========================================

BIN_DIR="$HOME/.local/bin"
SCRIPT_NAME="jr"
LOCK_FILE="/tmp/jr_sync.lock"

# 1. 语言识别 (Language Detection)
[[ "$LANG" =~ ^en ]] && LANG_EN=true || LANG_EN=false

# 2. 国际化字符串 (i18n)
if [ "$LANG_EN" = true ]; then
    STR_START=">>> Preparing to uninstall jr..."
    STR_REM_BIN="Removing binary file: $BIN_DIR/$SCRIPT_NAME"
    STR_REM_LOCK="Cleaning up lock file: $LOCK_FILE"
    STR_REM_PATH="Removing PATH configuration from"
    STR_DATA_SAFE="NOTE: Your journal data in ~/Documents/ remains INTACT."
    STR_DONE="Uninstall complete."
else
    STR_START=">>> 正在准备卸载 jr 日志工具..."
    STR_REM_BIN="正在移除二进制文件: $BIN_DIR/$SCRIPT_NAME"
    STR_REM_LOCK="正在清理锁文件: $LOCK_FILE"
    STR_REM_PATH="正在从配置文件中移除 PATH 记录:"
    STR_DATA_SAFE="提醒：位于 ~/Documents/ 的日志数据已被保留（我们不删数据）。"
    STR_DONE="卸载完成。"
fi

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}$STR_START${NC}"

# 3. 移除二进制文件
if [ -f "$BIN_DIR/$SCRIPT_NAME" ]; then
    rm "$BIN_DIR/$SCRIPT_NAME"
    echo -e "${GREEN}[✓] $STR_REM_BIN${NC}"
fi

# 4. 清理锁文件
if [ -f "$LOCK_FILE" ]; then
    rm "$LOCK_FILE"
    echo -e "${GREEN}[✓] $STR_REM_LOCK${NC}"
fi

# 5. 智能清理 Shell 配置文件 (PATH 移除)
detect_rc() {
    local current_shell=$(basename "$SHELL")
    if [[ "$current_shell" == "zsh" ]]; then
        echo "$HOME/.zshrc"
    elif [[ "$current_shell" == "bash" ]]; then
        echo "$HOME/.bashrc"
    else
        echo "$HOME/.profile"
    fi
}

RC_FILE=$(detect_rc)

if [ -f "$RC_FILE" ]; then
    # 使用 sed 移除包含 "jr CLI path" 的注释及其下一行 export 记录
    # 逻辑：匹配到注释行后，连同它下面那行一起删掉
    if grep -q "# jr CLI path" "$RC_FILE"; then
        sed -i '/# jr CLI path/,+1d' "$RC_FILE"
        echo -e "${GREEN}[✓] $STR_REM_PATH $RC_FILE${NC}"
    fi
fi

# 6. 结束提示
echo -e "\n${BLUE}==========================================${NC}"
echo -e "${GREEN}$STR_DONE${NC}"
echo -e "${RED}$STR_DATA_SAFE${NC}"
echo -e "${BLUE}==========================================${NC}"
