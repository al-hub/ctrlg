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

        # TTFT(첫 토큰 대기) 구간: 모델에게 주입된 실제 컨텍스트를 줄 단위로 노출
        # 컨텍스트가 소진되면 elapsed 타이머로 전환. 첫 토큰 도착 시 즉시 종료.
        local _ttft_start=$SECONDS
        (
            # tldr_context를 줄 단위로 순차 출력 (빈 줄 포함, 디버그 가시성 위해)
            # sleep 0.05초로 갱신 속도를 끌어올려 대기 체감을 줄이고 빠른 응답을 확보합니다.
            local ctx_shown=0
            while IFS= read -r ctx_line; do
                printf "[ctrlg]  ctx[%02d]: %s\n" "$ctx_shown" "$ctx_line" >&2
                ctx_shown=$((ctx_shown + 1))
                sleep 0.05
            done <<< "$tldr_context"
            # 컨텍스트 소진 후 elapsed 타이머
            while true; do
                sleep 2
                local elapsed=$(( SECONDS - _ttft_start ))
                printf "[ctrlg]  waiting : inferring... (%ds elapsed)\n" "$elapsed" >&2
            done
        ) &
        local heartbeat_pid=$!

        local first_token=true

        while read -r line; do
            [ -z "$line" ] && continue
            local token=$(echo "$line" | jq -r '.response' 2>/dev/null)
            if [ -n "$token" ] && [ "$token" != "null" ]; then
                # 첫 토큰 도착 즉시 컨텍스트 스트리머 종료 후 output 헤더 출력
                if [ "$first_token" = true ]; then
                    kill "$heartbeat_pid" &>/dev/null
                    wait "$heartbeat_pid" 2>/dev/null
                    local elapsed=$(( SECONDS - _ttft_start ))
                    printf "[ctrlg]  ttft    : %ds\n" "$elapsed" >&2
                    printf "[ctrlg]  output : " >&2
                    first_token=false
                fi
                response="${response}${token}"
                printf "%s" "$token" >&2
            fi
        done < <(curl -s -N --connect-timeout 3 --max-time 35 -X POST "${OLLAMA_HOST}/api/generate" -d "$json_data")

        # 안전 장치: curl 종료 후 컨텍스트 스트리머 잔존 시 강제 종료
        kill "$heartbeat_pid" &>/dev/null
        wait "$heartbeat_pid" 2>/dev/null

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
    local is_multi="$2"  # 1이면 다중 후보군 반환 모드
    if [ -z "$input" ]; then
        echo ""
        return 1
    fi
    local project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    
    # Fast Path 모듈 로드 및 시도 (Fast Path는 무조건 단일 후보군으로 간주)
    source "${project_dir}/src/fast_path.sh"
    local fast_cmd
    fast_cmd=$(check_fast_path "$input")
    if [ $? -eq 0 ]; then
        if [ "$is_multi" = "1" ]; then
            echo "CMD1: $fast_cmd"
            echo "DESC1: 빠른 매핑 명령어 (100% 매칭)"
        else
            echo "$fast_cmd"
        fi
        return 0
    fi
    
    # 진행 로그 헤더
    source "${project_dir}/config/config.env"
    printf "\n[ctrlg] query  : %s\n" "$input" >&2
    printf "[ctrlg]  host  : http://127.0.0.1:11434 (탐색 중...)\n" >&2
    
    # 쿼리 수행
    local ai_res=$(query_ai "$input" "${project_dir}/config/config.env" "${project_dir}/prompts/system_prompt.txt")
    
    # 만약 CMD1: 혹은 CMD:가 모두 없으면 1회 재시도 (단 빈 응답/타임아웃은 제외)
    if [[ "$ai_res" != *"[cC][mM][dD]1:"* ]] && [[ "$ai_res" != *"[cC][mM][dD]:"* ]] && [ -n "$ai_res" ]; then
        ai_res=$(query_ai "$input" "${project_dir}/config/config.env" "${project_dir}/prompts/system_prompt.txt")
    fi

    # 다중 후보군 또는 단일 후보군 추출
    local cmd1="" desc1=""
    local cmd2="" desc2=""
    local cmd3="" desc3=""

    # 1. 신규 포맷 (CMD1/DESC1) 파싱 시도 (단어 경계 누락 대비 강제 줄바꿈 전처리)
    local formatted_res=$(echo "$ai_res" | sed -E 's/([dD][eE][sS][cC][1-3]:|[cC][mM][dD][2-3]:)/\n\1/g')

    if echo "$formatted_res" | grep -q -i "^CMD1:"; then
        cmd1=$(echo "$formatted_res" | grep -i "^CMD1:" | head -n 1 | sed -E 's/^[cC][mM][dD]1:[[:space:]]*//i' | xargs)
        desc1=$(echo "$formatted_res" | grep -i "^DESC1:" | head -n 1 | sed -E 's/^[dD][eE][sS][cC]1:[[:space:]]*//i' | xargs)
        cmd2=$(echo "$formatted_res" | grep -i "^CMD2:" | head -n 1 | sed -E 's/^[cC][mM][dD]2:[[:space:]]*//i' | xargs)
        desc2=$(echo "$formatted_res" | grep -i "^DESC2:" | head -n 1 | sed -E 's/^[dD][eE][sS][cC]2:[[:space:]]*//i' | xargs)
        cmd3=$(echo "$formatted_res" | grep -i "^CMD3:" | head -n 1 | sed -E 's/^[cC][mM][dD]3:[[:space:]]*//i' | xargs)
        desc3=$(echo "$formatted_res" | grep -i "^DESC3:" | head -n 1 | sed -E 's/^[dD][eE][sS][cC]3:[[:space:]]*//i' | xargs)
    fi

    # 2. 파싱 실패 시 레거시 포맷 (CMD: 등) 파싱 시도 및 CMD1로 매핑
    if [ -z "$cmd1" ]; then
        local cmd_line=$(echo "$ai_res" | grep -m1 -i "^CMD:")
        local legacy_cmd=""
        if [ -n "$cmd_line" ]; then
            legacy_cmd=$(echo "$cmd_line" | sed -E 's/^[cC][mM][dD]://i')
            legacy_cmd=$(echo "$legacy_cmd" | sed -E 's/[cC][mM][dD]:.*$//' | sed 's/`.*$//' | xargs)
        else
            local backtick_cmd=$(echo "$ai_res" | grep -oP '`[^`]+`' | head -1 | tr -d '`')
            if [ -n "$backtick_cmd" ]; then
                legacy_cmd="$backtick_cmd"
            else
                local first_line=$(echo "$ai_res" | head -n 1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                local first_word=$(echo "$first_line" | awk '{print $1}')
                local is_whitelisted=0
                for w in $WHITELIST_COMMANDS; do
                    if [ "$first_word" = "$w" ]; then
                        is_whitelisted=1
                        break
                    fi
                done
                if [ $is_whitelisted -eq 1 ]; then
                    legacy_cmd=$(echo "$first_line" | sed 's/`.*$//' | xargs)
                fi
            fi
        fi

        if [ -n "$legacy_cmd" ]; then
            cmd1="$legacy_cmd"
            desc1="AI 추천 명령어"
        fi
    fi

    # 보안 검증 필터 적용
    source "${project_dir}/src/security.sh"
    
    # 각 명령어 후보에 대해 개별 보안 검증 수행
    local valid_cmd1="" valid_cmd2="" valid_cmd3=""

    if [ -n "$cmd1" ]; then
        validate_command "$cmd1" "$WHITELIST_COMMANDS"
        [ $? -eq 0 ] && valid_cmd1="$cmd1"
    fi
    if [ -n "$cmd2" ]; then
        validate_command "$cmd2" "$WHITELIST_COMMANDS"
        [ $? -eq 0 ] && valid_cmd2="$cmd2"
    fi
    if [ -n "$cmd3" ]; then
        validate_command "$cmd3" "$WHITELIST_COMMANDS"
        [ $? -eq 0 ] && valid_cmd3="$cmd3"
    fi

    # 최종 결과 출력 분기
    if [ "$is_multi" = "1" ]; then
        # 다중 출력 모드: 라벨 형식 출력
        local has_any=0
        if [ -n "$valid_cmd1" ]; then
            echo "CMD1: $valid_cmd1"
            echo "DESC1: ${desc1:-AI 추천 1순위}"
            has_any=1
        fi
        if [ -n "$valid_cmd2" ]; then
            echo "CMD2: $valid_cmd2"
            echo "DESC2: ${desc2:-AI 추천 2순위}"
            has_any=1
        fi
        if [ -n "$valid_cmd3" ]; then
            echo "CMD3: $valid_cmd3"
            echo "DESC3: ${desc3:-AI 추천 3순위}"
            has_any=1
        fi

        if [ $has_any -eq 1 ]; then
            # 로그 정보
            printf "[ctrlg]  security: multi-command validation complete\n" >&2
            return 0
        else
            printf "[ctrlg]  result  : BLOCKED (security risk detected)\n" >&2
            return 1
        fi
    else
        # 단일 출력 모드: 기존 호환성 유지
        if [ -n "$valid_cmd1" ]; then
            printf "[ctrlg]  security: validating [%s]\n" "$valid_cmd1" >&2
            printf "[ctrlg]  --\n" >&2
            printf "[ctrlg]  cmd     : %s\n" "$valid_cmd1" >&2
            printf "[ctrlg]  --\n" >&2
            echo "$valid_cmd1"
            return 0
        else
            # CMD가 모두 없거나 보안 차단 시
            local clean_response=$(echo "$ai_res" | tr -d '\r' | perl -0777 -pe 's/Thinking\.\.\..*?\.\.\.done thinking\.\n?//gs' | perl -0777 -pe 's/<think>.*?<\/think>\n?//gs' | sed '/^\s*$/d')
            if [ -n "$clean_response" ]; then
                printf "[ctrlg]  result  : NATURAL_LANG\n" >&2
                echo "$clean_response"
            else
                printf "[ctrlg]  result  : EMPTY\n" >&2
                echo ""
            fi
            return 1
        fi
    fi
}
