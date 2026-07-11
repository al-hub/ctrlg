#!/usr/bin/env bash

# AI 모델 호출 및 파싱 모듈
query_ai() {
    local input="$1"
    local config_file="$2"
    local prompt_file="$3"

    # 설정 파일 로드
    source "$config_file"
    local system_prompt=$(cat "$prompt_file")

    # WSL 호스트 IP 자동 탐지 및 셋업
    if [ "$OLLAMA_HOST" = "http://127.0.0.1:11434" ]; then
        # WSL 환경인 경우 호스트 게이트웨이 주소 우선 탐색
        if grep -q microsoft /proc/version 2>/dev/null; then
            local host_ip=$(grep nameserver /etc/resolv.conf | awk '{print $2}')
            if [ -n "$host_ip" ]; then
                OLLAMA_HOST="http://${host_ip}:11434"
            fi
        fi
    fi

    local response=""
    if command -v curl &>/dev/null && command -v jq &>/dev/null; then
        response=$(curl -s -X POST "${OLLAMA_HOST}/api/generate" -d "{
            \"model\": \"${OLLAMA_MODEL}\",
            \"prompt\": \"system: ${system_prompt}\nuser: ${input}\",
            \"stream\": false
        }" | jq -r '.response' 2>/dev/null | sed '/^\s*$/d')
    else
        response=$(ollama run "${OLLAMA_MODEL}" "System: ${system_prompt}\nUser: ${input}" | sed '/^\s*$/d')
    fi

    if [ -z "$response" ]; then
        echo ""
        return 1
    fi

    # 생각 과정(Thinking Process) 및 캐리지 리턴(\r) 제거
    local clean_response=$(echo "$response" | tr -d '\r' | perl -0777 -pe 's/Thinking\.\.\..*?\.\.\.done thinking\.\n?//gs' | perl -0777 -pe 's/<think>.*?<\/think>\n?//gs' | sed '/^\s*$/d')
    echo "$clean_response"
    return 0
}
