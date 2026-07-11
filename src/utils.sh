#!/usr/bin/env bash

# 로그 및 화면 출력 포맷터
log_info() {
    echo -e "\e[1;32m[INFO]\e[0m $*"
}

log_warn() {
    echo -e "\e[1;33m[WARN]\e[0m $*"
}

log_error() {
    echo -e "\e[1;31m[ERROR]\e[0m $*"
}

# 클립보드 복사 유틸리티
copy_to_clipboard() {
    local text="$1"
    if command -v xclip &>/dev/null; then
        echo -n "$text" | xclip -selection clipboard
        return 0
    elif command -v clip.exe &>/dev/null; then
        echo -n "$text" | clip.exe
        return 0
    fi
    return 1
}
