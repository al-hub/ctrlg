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
    export LAST_RAG_MATCHES=""
    local tldr_context=$(get_tldr_context "$input")
    if [ -n "$tldr_context" ]; then
        system_prompt="${system_prompt}

아래 제공되는 해당 명령어의 공식 사용 템플릿(Context)을 참고하여 최적의 인자(Arguments) 조합을 완성하세요:
${tldr_context}"
    fi

    # RAG 매칭 완료 피드백 (매칭된 파일 데이터 노출)
    if [ -n "$LAST_RAG_MATCHES" ]; then
        local clean_matches=$(echo "$LAST_RAG_MATCHES" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        printf "\e[1A\e[2K🔍 ctrlg: RAG 지식 매칭 완료 [tldr: %s]\n" "$clean_matches" >&2
        sleep 0.8
    fi

    # Ollama 호스트 최적 경로 탐색 및 전환 (WSL 호스트 IP 대응 포함)
    setup_ollama_host
    
    # AI 모델 가동 및 연결 데이터 노출
    printf "\e[1A\e[2K🔍 ctrlg: AI 추론 실행 중... [model: ${OLLAMA_MODEL} @ ${OLLAMA_HOST}]\n" >&2

    local response=""
    if command -v curl &>/dev/null && command -v jq &>/dev/null; then
        # jq를 사용해 JSON 페이로드를 안전하게 이스케이프 조립 (stream: true 설정)
        local json_data=$(jq -n \
            --arg model "${OLLAMA_MODEL}" \
            --arg prompt "system: ${system_prompt}
user: ${input}" \
            --argjson stream true \
            '{model: $model, prompt: $prompt, stream: $stream}')

        # 2-1단계: 매칭된 RAG 문서의 실제 예제 명령어를 실시간으로 순환 노출
        local examples=()
        local files=()
        local tldr_path="${project_dir}/resources/tldr"
        for f in $LAST_RAG_MATCHES; do
            local file_path="${tldr_path}/${f}"
            if [ -f "$file_path" ]; then
                local cmd_name="${f%.md}"
                # 마크다운 내의 실제 예제 명령어 추출
                while read -r line; do
                    if [ -n "$line" ]; then
                        examples+=("$line")
                        files+=("$f")
                    fi
                done < <(grep -E "^[[:space:]]*${cmd_name}\b" "$file_path" | sed 's/^[[:space:]]*//')
            fi
        done

        # 매칭된 실제 RAG 데이터 리포터 비동기 가동
        (
            local idx=0
            local count=${#examples[@]}
            if [ $count -eq 0 ]; then
                local dots=""
                while true; do
                    dots="${dots}."
                    if [ ${#dots} -gt 3 ]; then dots=""; fi
                    printf "\r\e[2K🔍 ctrlg: AI 추천 명령어 분석 및 생성 중%s   " "$dots" >&2
                    sleep 0.5
                done
            else
                while true; do
                    local cur_file="${files[$idx]}"
                    local cur_example="${examples[$idx]}"
                    printf "\r\e[2K🔍 ctrlg: RAG 지식 참조 중 ➡️  [%s: %s] (연산 중...)" "$cur_file" "$cur_example" >&2
                    idx=$(( (idx + 1) % count ))
                    sleep 0.7
                done
            fi
        ) &
        local loader_pid=$!

        local first_token=true

        # curl --no-buffer와 프로세스 치환으로 실시간 1토큰 단위 렌더링 스트리밍
        while read -r line; do
            [ -z "$line" ] && continue
            local token=$(echo "$line" | jq -r '.response' 2>/dev/null)
            if [ -n "$token" ] && [ "$token" != "null" ]; then
                # 첫 번째 토큰 도착 즉시 백그라운드 비동기 로더 프로세스 강제 종료
                if [ "$first_token" = true ]; then
                    kill "$loader_pid" &>/dev/null
                    wait "$loader_pid" 2>/dev/null
                    # 실시간 명령어 생성 갱신 모드로 헤더 전환
                    printf "\r\e[2K🔍 ctrlg: AI 추천 명령어 실시간 생성 중 ➡️  " >&2
                    first_token=false
                fi
                response="${response}${token}"
                printf "%s" "$token" >&2
            fi
        done < <(curl -s -N --connect-timeout 3 --max-time 25 -X POST "${OLLAMA_HOST}/api/generate" -d "$json_data")

        # 안전 장치: 루프 종료 후 비동기 로더 강제 종료 상태 보장
        kill "$loader_pid" &>/dev/null
        wait "$loader_pid" 2>/dev/null
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
    
    # 1단계 피드백: 연결 상태 체크 (호스트 주소 노출)
    source "${project_dir}/config/config.env"
    printf "🔍 ctrlg: Ollama 호스트 탐색 중... [http://127.0.0.1:11434]\n" >&2
    
    # 쿼리 수행
    local ai_res=$(query_ai "$input" "${project_dir}/config/config.env" "${project_dir}/prompts/system_prompt.txt")
    
    # 첫 줄 추출
    local first_line=$(echo "$ai_res" | head -n 1)
    
    # CMD: 접두사가 존재하면 값만 추출하여 출력, 아니면 입력어 그대로 출력 (대체)
    if [[ "$first_line" =~ ^CMD: ]]; then
        local cmd="${first_line#CMD:}"
        cmd=$(echo "$cmd" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        
        # 3단계 피드백: 보안성 검증 (보안 검사 대상 명령어 노출)
        printf "\e[1A\e[2K🔍 ctrlg: 보안성 검증 중... [cmd: %s]\n" "$cmd" >&2
        
        # 위젯용 보안성 검사 가동
        source "${project_dir}/src/security.sh"
        validate_command "$cmd" "$WHITELIST_COMMANDS"
        if [ $? -eq 0 ]; then
            # 4단계 피드백: 통과 완료
            printf "\e[1A\e[2K🔍 ctrlg: 보안 검사 통과 및 치환 완료\n" >&2
            echo "$cmd"
        else
            # 보안 실패 시 안전 롤백 및 에러 알림
            printf "\e[1A\e[2K⚠️  ctrlg: 보안 위험이 감지되어 원본을 유지합니다.\n" >&2
            echo "$input"
        fi
    else
        # 치환 실패 시에도 진행 라인을 지우고 원본 반환
        printf "\e[1A\e[2K" >&2
        echo "$input"
    fi
}
