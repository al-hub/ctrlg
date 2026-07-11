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

# Ollama 호스트 포트 동적 헬스체크 및 설정 함수
setup_ollama_host() {
    # 설정에 등록된 기본 주소를 읽어옵니다. (기본값: http://127.0.0.1:11434)
    local default_host="$OLLAMA_HOST"
    if [ -z "$default_host" ]; then
        default_host="http://127.0.0.1:11434"
    fi

    # 1. 먼저 기본 주소(127.0.0.1)로 즉시 헬스체크 (타임아웃 0.5초)
    curl -s --connect-timeout 0.5 "${default_host}/api/tags" &>/dev/null
    if [ $? -eq 0 ]; then
        OLLAMA_HOST="$default_host"
        return 0
    fi

    # 2. 실패했고, WSL 환경인 경우 호스트 OS IP 접근 시도
    if grep -q microsoft /proc/version 2>/dev/null; then
        local host_ip=$(grep nameserver /etc/resolv.conf | awk '{print $2}')
        if [ -n "$host_ip" ]; then
            local host_addr="http://${host_ip}:11434"
            # 호스트 IP 주소로 즉시 헬스체크 (타임아웃 0.5초)
            curl -s --connect-timeout 0.5 "${host_addr}/api/tags" &>/dev/null
            if [ $? -eq 0 ]; then
                OLLAMA_HOST="$host_addr"
                return 0
            fi
        fi
    fi

    # 3. 모두 실패 시 기본 주소 유지 (이후 단계에서 타임아웃 에러 처리되도록 함)
    OLLAMA_HOST="$default_host"
    return 1
}
