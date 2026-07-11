#!/usr/bin/env bash

# 명령어 실패 원인 분석 및 해결안 출력
analyze_command_error() {
    local error_cmd="$1"
    local exit_status="$2"
    local project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

    # 설정 로드
    source "${project_dir}/config/config.env"

    local system_prompt="당신은 리눅스 명령어 디버거입니다.
사용자가 입력한 명령어 '$error_cmd'가 종료 코드 $exit_status 로 실패했습니다.
실패한 원인을 2줄 이내로 간결히 설명하고, 정상적으로 실행될 수 있는 교정 명령어를 '💡 제안: 명령어' 형식으로만 추천하세요."

    # WSL 호스트 IP 대응
    if [ "$OLLAMA_HOST" = "http://127.0.0.1:11434" ]; then
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
            \"prompt\": \"system: ${system_prompt}\nuser: 에러 해결책을 알려줘\",
            \"stream\": false
        }" | jq -r '.response' 2>/dev/null | sed '/^\s*$/d')
    else
        response=$(ollama run "${OLLAMA_MODEL}" "System: ${system_prompt}\nUser: 에러 해결책을 알려줘" | sed '/^\s*$/d')
    fi

    if [ -n "$response" ]; then
        local clean_response=$(echo "$response" | tr -d '\r' | perl -0777 -pe 's/Thinking\.\.\..*?\.\.\.done thinking\.\n?//gs' | perl -0777 -pe 's/<think>.*?<\/think>\n?//gs' | sed '/^\s*$/d')
        # 출력
        echo -e "\n${clean_response}"
    fi
}
