#!/usr/bin/env bash

# AI 모델 호출 및 파싱 모듈
query_ai() {
    local input="$1"
    local config_file="$2"
    local prompt_file="$3"
    
    local project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    
    # RAG 매처 모듈 로드
    source "${project_dir}/src/rag_matcher.sh"

    # 설정 파일 로드
    source "$config_file"
    local system_prompt=$(cat "$prompt_file")

    # 1. RAG 컨텍스트 검색 및 결합
    local tldr_context=$(get_tldr_context "$input")
    if [ -n "$tldr_context" ]; then
        system_prompt="${system_prompt}

아래 제공되는 해당 명령어의 공식 사용 템플릿(Context)을 참고하여 최적의 인자(Arguments) 조합을 완성하세요:
${tldr_context}"
    fi

    # WSL 호스트 IP 자동 탐지 및 셋업
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
        # jq를 사용해 JSON 페이로드를 안전하게 이스케이프 조립 (줄바꿈/따옴표 이스케이프 해결)
        local json_data=$(jq -n \
            --arg model "${OLLAMA_MODEL}" \
            --arg prompt "system: ${system_prompt}
user: ${input}" \
            --argjson stream false \
            '{model: $model, prompt: $prompt, stream: $stream}')

        # 연결 타임아웃 3초, 최대 수행 시간 10초 제한 추가 (무한 대기 방지)
        response=$(curl -s --connect-timeout 3 --max-time 10 -X POST "${OLLAMA_HOST}/api/generate" -d "$json_data" | jq -r '.response' 2>/dev/null | sed '/^\s*$/d')
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

# 쉘 위젯 통신을 위한 날것의 CMD 전용 질의 함수
raw_query_ai() {
    local input="$1"
    local project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    
    # Fast Path 모듈 로드 및 시도 (선언과 대입 분리로 종료 코드 덮어쓰기 방지)
    source "${project_dir}/src/fast_path.sh"
    local fast_cmd
    fast_cmd=$(check_fast_path "$input")
    if [ $? -eq 0 ]; then
        echo "$fast_cmd"
        return 0
    fi
    
    # 쿼리 수행
    local ai_res=$(query_ai "$input" "${project_dir}/config/config.env" "${project_dir}/prompts/system_prompt.txt")
    
    # 첫 줄 추출
    local first_line=$(echo "$ai_res" | head -n 1)
    
    # CMD: 접두사가 존재하면 값만 추출하여 출력, 아니면 입력어 그대로 출력 (대체)
    if [[ "$first_line" =~ ^CMD: ]]; then
        local cmd="${first_line#CMD:}"
        echo "$cmd" | xargs
    else
        # CMD 매핑 실패 시 쉘 버퍼를 흐트러뜨리지 않기 위해 빈칸 대신 입력어 원본 유지
        echo "$input"
    fi
}
