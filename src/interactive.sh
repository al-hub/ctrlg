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

    # 1. 히스토리 파일 읽어서 질의어(입력값) 목록 생성 (중복 제거 및 최신순 정렬)
    local history_items=""
    if [ -f "$history_file" ]; then
        # 히스토리 파일에서 첫 번째 필드(질의어)만 추출하여 중복 없이 최신순 정렬
        history_items=$(tac "$history_file" 2>/dev/null | cut -f1 | awk '!seen[$0]++')
    fi

    # fzf에 보낼 전체 리스트 구성
    local fzf_input=""
    if [ -n "$initial_query" ]; then
        fzf_input="📝 현재 입력어: $initial_query\n"
    fi
    fzf_input="${fzf_input}🆕 새로운 질의 입력하기\n${history_items}"

    # 2. 질의 선택 창 띄우기
    local fzf_out
    fzf_out=$(printf "$fzf_input" | fzf \
        --height 15 \
        --layout=reverse \
        --header "🤖 ctrlg 질의 선택 (과거 질의 선택 또는 새로운 자연어 입력)" \
        --query "$initial_query" \
        --print-query)

    local fzf_status=$?
    if [ $fzf_status -ne 0 ] && [ -z "$fzf_out" ]; then
        return 1
    fi

    # fzf_out의 첫 번째 줄은 입력된 검색어(query), 두 번째 줄은 선택한 항목(selection)
    local typed_query=$(echo "$fzf_out" | head -n 1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    local selection=$(echo "$fzf_out" | tail -n 1)

    # 3. 질의어 결정
    local final_query=""
    if [[ "$selection" == "📝 현재 입력어:"* ]]; then
        final_query="$initial_query"
    elif [[ "$selection" == "🆕 새로운 질의 입력하기" ]] || [ -z "$selection" ]; then
        # 검색창에 타이핑한 텍스트가 있으면 질의어로 사용하고, 없으면 수동 입력 받음
        if [ -n "$typed_query" ] && [ "$typed_query" != "🆕 새로운 질의 입력하기" ]; then
            final_query="$typed_query"
        else
            printf "🔍 새로운 자연어 질의 입력: " >&2
            read -r final_query < /dev/tty
        fi
    else
        # 과거 질의어 목록에서 선택한 경우
        final_query="$selection"
    fi

    if [ -z "$final_query" ]; then
        return 1
    fi

    # 4. 선택된 질의어를 AI로 넘겨서 추천 명령어 획득
    echo "" >&2
    echo "🤖 AI 추천 명령어를 생성하는 중..." >&2
    echo "   [질의어: $final_query]" >&2

    local res_file=$(mktemp)
    "${PROJECT_DIR}/bin/ctrlg" --raw "$final_query" > "$res_file"
    local recommended_cmd=$(cat "$res_file" | xargs)
    rm -f "$res_file"

    if [ -z "$recommended_cmd" ]; then
        echo "❌ 추천 명령어를 생성하지 못했습니다." >&2
        return 1
    fi

    # 성공 시 질의어를 히스토리 로그에 추가 저장
    echo "$final_query" >> "$history_file"

    # 최종 선택한 명령어 출력 (stdout)
    echo "$recommended_cmd"
    return 0
}
