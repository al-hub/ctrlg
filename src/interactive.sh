#!/usr/bin/env bash

# ctrlg 대화형 (Interactive) FZF 모드 모듈
# 모든 UI 출력 및 로그는 stderr로 보내고, 최종 선택된 명령어만 stdout으로 출력합니다.

run_interactive_mode() {
    local query="$1"
    local initial_query="$query"
    local history_file="$HOME/.config/ctrlg/history.log"
    
    mkdir -p "$(dirname "$history_file")"
    touch "$history_file"

    # fzf 존재 여부 확인
    if ! command -v fzf &>/dev/null; then
        echo "❌ [오류] 대화형 모드를 사용하려면 'fzf'가 설치되어 있어야 합니다." >&2
        return 1
    fi

    # 1. 히스토리 파일 읽어서 목록 생성 (중복 제거 및 최신순 정렬)
    local history_items=""
    if [ -f "$history_file" ]; then
        # tac을 이용하여 최신 기록이 위로 올라오게 하고 awk로 중복 제거
        history_items=$(tac "$history_file" 2>/dev/null | awk -F'\t' '!seen[$1]++ {print $1 "  👉  " $2}')
    fi

    # fzf에 보낼 전체 리스트 구성
    local fzf_input=""
    if [ -n "$initial_query" ]; then
        fzf_input="📝 현재 입력어로 AI 추천 받기: $initial_query\n"
    fi
    fzf_input="${fzf_input}🆕 새로운 질의 입력하기\n${history_items}"

    # 2. 히스토리 및 질의 선택 창 띄우기
    local fzf_out
    fzf_out=$(printf "$fzf_input" | fzf \
        --height 15 \
        --layout=reverse \
        --header "🤖 ctrlg 히스토리 (검색/선택 또는 새로운 자연어 입력)" \
        --query "$initial_query" \
        --print-query)

    local fzf_status=$?
    if [ $fzf_status -ne 0 ] && [ -z "$fzf_out" ]; then
        return 1
    fi

    # fzf_out의 첫 번째 줄은 입력된 검색어(query), 두 번째 줄은 선택한 항목(selection)
    local typed_query=$(echo "$fzf_out" | head -n 1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    local selection=$(echo "$fzf_out" | tail -n 1)

    # 3. 결과에 따른 분기 처리
    if [[ "$selection" == *"  👉  "* ]]; then
        # 히스토리에서 항목을 선택한 경우: 저장되어 있던 명령어를 즉시 적용
        local cmd="${selection#*  👉  }"
        echo "$cmd"
        return 0
    fi

    # 4. 새로운 질의를 통한 AI 명령어 추천 생성
    local final_query=""
    if [[ "$selection" == "📝 현재 입력어로 AI 추천 받기:"* ]]; then
        final_query="$initial_query"
    elif [[ "$selection" == "🆕 새로운 질의 입력하기" ]] || [ -z "$selection" ]; then
        # 검색창에 타이핑한 텍스트가 있으면 질의어로 사용하고, 없으면 수동 입력 받음
        if [ -n "$typed_query" ] && [ "$typed_query" != "🆕 새로운 질의 입력하기" ]; then
            final_query="$typed_query"
        else
            printf "🔍 새로운 자연어 질의 입력: " >&2
            read -r final_query < /dev/tty
        fi
    fi

    if [ -z "$final_query" ]; then
        return 1
    fi

    echo "" >&2
    echo "🤖 AI 추천 명령어를 생성하는 중..." >&2

    local res_file=$(mktemp)
    "${PROJECT_DIR}/bin/ctrlg" --raw "$final_query" > "$res_file"
    local recommended_cmd=$(cat "$res_file" | xargs)
    rm -f "$res_file"

    if [ -z "$recommended_cmd" ]; then
        echo "❌ 추천 명령어를 생성하지 못했습니다." >&2
        return 1
    fi

    # 성공 시 히스토리 로그 파일에 추가 저장 (포맷: 질의 [TAB] 명령어)
    printf "%s\t%s\n" "$final_query" "$recommended_cmd" >> "$history_file"

    # 최종 선택한 명령어 출력
    echo "$recommended_cmd"
    return 0
}
