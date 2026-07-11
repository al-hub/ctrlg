#!/usr/bin/env bash

# AI 모델 호출 및 파싱 모듈
# 진행 로그는 모두 Stderr(>&2)로 출력하며, 덮어쓰기 없이 누적 로그 방식으로 표시됩니다.

_log() {
    printf "[ctrlg] %s\n" "$1" >&2
}

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
    # 서브쉘 스코프에 의한 변수 소멸 방지를 위해 부모 쉘에서 RAG 매칭 목록 직접 수집
    local tldr_path="${project_dir}/resources/tldr"
    export LAST_RAG_MATCHES=""
    for word in $input; do
        local lower_word=$(echo "$word" | tr '[:upper:]' '[:lower:]' | tr -d '[:punct:]')
        case "$lower_word" in
            하위폴더|디렉토리|검색|찾기|파일명|확장자) lower_word="find" ;;
            갯수|개수|라인수|라인|카운트) lower_word="wc" ;;
            압축|zip) lower_word="zip" ;;
        esac
        if [ -n "$lower_word" ] && [ -f "${tldr_path}/${lower_word}.md" ]; then
            if [[ "$LAST_RAG_MATCHES" != *"${lower_word}.md"* ]]; then
                LAST_RAG_MATCHES="${LAST_RAG_MATCHES}${lower_word}.md "
            fi
        fi
    done

    local tldr_context=$(get_tldr_context "$input")
    if [ -n "$tldr_context" ]; then
        system_prompt="${system_prompt}

아래 제공되는 해당 명령어의 공식 사용 템플릿(Context)을 참고하여 최적의 인자(Arguments) 조합을 완성하세요:
${tldr_context}"
    fi

    # RAG 매칭 완료 로그 출력
    if [ -n "$LAST_RAG_MATCHES" ]; then
        local clean_matches=$(echo "$LAST_RAG_MATCHES" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        _log "  rag   : knowledge matched [${clean_matches}]"
    fi

    # Ollama 호스트 최적 경로 탐색 및 전환 (WSL 호스트 IP 대응 포함)
    setup_ollama_host
    
    # AI 모델 가동 로그 출력
    _log "  model : ${OLLAMA_MODEL} @ ${OLLAMA_HOST}"
    _log "  status: generating..."

    local response=""
    if command -v curl &>/dev/null && command -v jq &>/dev/null; then
        # jq를 사용해 JSON 페이로드를 안전하게 이스케이프 조립 (stream: true 설정)
        local json_data=$(jq -n \
            --arg model "${OLLAMA_MODEL}" \
            --arg prompt "system: ${system_prompt}
user: ${input}" \
            --argjson stream true \
            '{model: $model, prompt: $prompt, stream: $stream}')

        # RAG 예제 명령어 수집 (누적 로그 방식으로 사전 노출)
        local examples=()
        for f in $LAST_RAG_MATCHES; do
            local file_path="${tldr_path}/${f}"
            if [ -f "$file_path" ]; then
                local cmd_name="${f%.md}"
                while read -r ex_line; do
                    [ -n "$ex_line" ] && examples+=("  ref   : [${f}] ${ex_line}")
                done < <(grep -E "^[[:space:]]*${cmd_name}\b" "$file_path" | sed 's/^[[:space:]]*//')
            fi
        done

        # 수집된 RAG 예제를 첫 토큰 대기 전에 누적 로그로 출력 (최대 5개)
        local max_preview=5
        local shown=0
        for ex in "${examples[@]}"; do
            [ $shown -ge $max_preview ] && break
            printf "[ctrlg] %s\n" "$ex" >&2
            shown=$((shown + 1))
        done

        # curl 스트리밍 수신 및 첫 토큰 도착 시 헤더 출력
        local first_token=true
        printf "[ctrlg]  output: " >&2

        while read -r line; do
            [ -z "$line" ] && continue
            local token=$(echo "$line" | jq -r '.response' 2>/dev/null)
            if [ -n "$token" ] && [ "$token" != "null" ]; then
                response="${response}${token}"
                printf "%s" "$token" >&2
            fi
        done < <(curl -s -N --connect-timeout 3 --max-time 25 -X POST "${OLLAMA_HOST}/api/generate" -d "$json_data")

        # 스트리밍 완료 후 줄바꿈
        printf "\n" >&2
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
    
    # 진행 로그 헤더
    source "${project_dir}/config/config.env"
    printf "\n[ctrlg] query  : %s\n" "$input" >&2
    printf "[ctrlg]  host  : http://127.0.0.1:11434 (탐색 중...)\n" >&2
    
    # 쿼리 수행
    local ai_res=$(query_ai "$input" "${project_dir}/config/config.env" "${project_dir}/prompts/system_prompt.txt")
    
    # 첫 줄 추출
    local first_line=$(echo "$ai_res" | head -n 1)
    
    if [[ "$first_line" =~ ^CMD: ]]; then
        local cmd="${first_line#CMD:}"
        cmd=$(echo "$cmd" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        
        # 보안 검증 로그
        printf "[ctrlg]  security: validating [%s]\n" "$cmd" >&2
        
        source "${project_dir}/src/security.sh"
        validate_command "$cmd" "$WHITELIST_COMMANDS"
        if [ $? -eq 0 ]; then
            printf "[ctrlg]  result  : OK -> substituted\n" >&2
            echo "$cmd"
        else
            printf "[ctrlg]  result  : BLOCKED (security risk detected, keeping original)\n" >&2
            echo "$input"
        fi
    else
        printf "[ctrlg]  result  : FAIL (no CMD prefix, keeping original)\n" >&2
        echo "$input"
    fi
}
