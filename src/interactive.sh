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

    local current_query="$initial_query"
    local show_history_prompt=true

    while true; do
        local final_query=""

        if [ "$show_history_prompt" = true ]; then
            # 1. 히스토리 파일 읽어서 질의어(입력값) 목록 생성
            local history_items=""
            if [ -f "$history_file" ]; then
                history_items=$(tac "$history_file" 2>/dev/null | cut -f1 | awk '!seen[$0]++')
            fi

            # fzf에 보낼 전체 리스트 구성
            local fzf_input=""
            if [ -n "$current_query" ]; then
                fzf_input="📝 현재 입력어: $current_query\n"
            fi
            fzf_input="${fzf_input}🆕 새로운 질의 입력하기\n${history_items}"

            # 2. 질의 선택 창 띄우기
            local fzf_out
            fzf_out=$(printf "$fzf_input" | fzf \
                --height 15 \
                --layout=reverse \
                --header "🤖 ctrlg 질의 선택 (과거 이력 'Tab' 또는 'Ctrl+E'로 수정 편집 가능)" \
                --query "$current_query" \
                --bind "tab:replace-query,ctrl-e:replace-query" \
                --print-query)

            local fzf_status=$?
            if [ $fzf_status -ne 0 ] && [ -z "$fzf_out" ]; then
                return 1
            fi

            # fzf_out의 첫 번째 줄은 입력된 검색어(query), 두 번째 줄은 선택한 항목(selection)
            local typed_query=$(echo "$fzf_out" | head -n 1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            local selection=$(echo "$fzf_out" | tail -n 1)

            # 3. 질의어 결정
            if [[ "$selection" == "📝 현재 입력어:"* ]]; then
                final_query="$current_query"
            elif [[ "$selection" == "🆕 새로운 질의 입력하기" ]] || [ -z "$selection" ]; then
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
        else
            # 루프 도중 재시도(수정) 시 직접 질의를 수동 입력받음
            printf "🔍 자연어 질의 수정 입력: " >&2
            read -r final_query < /dev/tty
        fi

        if [ -z "$final_query" ]; then
            return 1
        fi

        # 4. 선택된 질의어를 AI로 넘겨서 추천 명령어 획득
        echo "" >&2
        echo "🤖 AI 추천 명령어를 생성하는 중..." >&2
        echo "   [질의어: $final_query]" >&2

        local res_file=$(mktemp)
        "${PROJECT_DIR}/bin/ctrlg" --raw-multi "$final_query" > "$res_file"
        
        # 후보군 파싱
        local cmd1=$(grep -i "^CMD1:" "$res_file" | head -n 1 | sed -E 's/^[cC][mM][dD]1:[[:space:]]*//i' | xargs)
        local desc1=$(grep -i "^DESC1:" "$res_file" | head -n 1 | sed -E 's/^[dD][eE][sS][cC]1:[[:space:]]*//i' | xargs)
        local cmd2=$(grep -i "^CMD2:" "$res_file" | head -n 1 | sed -E 's/^[cC][mM][dD]2:[[:space:]]*//i' | xargs)
        local desc2=$(grep -i "^DESC2:" "$res_file" | head -n 1 | sed -E 's/^[dD][eE][sS][cC]2:[[:space:]]*//i' | xargs)
        local cmd3=$(grep -i "^CMD3:" "$res_file" | head -n 1 | sed -E 's/^[cC][mM][dD]3:[[:space:]]*//i' | xargs)
        local desc3=$(grep -i "^DESC3:" "$res_file" | head -n 1 | sed -E 's/^[dD][eE][sS][cC]3:[[:space:]]*//i' | xargs)

        # 만약 추천된 유효 명령어가 아예 없는 경우 (보안 차단 또는 에러)
        if [ -z "$cmd1" ]; then
            echo "" >&2
            # Stderr 로그에 남은 결과(BLOCKED 등)를 출력하여 피드백 제공
            cat "$res_file" >&2
            rm -f "$res_file"
            
            # 다음 인터랙션 분기 (다시 입력할 수 있도록 재시도 루프로 전환)
            printf "\n❓ 어떻게 하시겠습니까? (1: 재시도, 2: 취소): " >&2
            local choice
            read -r choice < /dev/tty
            if [ "$choice" = "1" ]; then
                show_history_prompt=false
                current_query=""
                continue
            else
                return 1
            fi
        fi

        # 후보군 개수 계산
        local count=0
        [ -n "$cmd1" ] && count=$((count + 1))
        [ -n "$cmd2" ] && count=$((count + 1))
        [ -n "$cmd3" ] && count=$((count + 1))

        # UX 보강 1 & 2: 단일 후보군(혹은 Fast Path) 매칭 시 즉시 적용 및 주입
        if [ $count -eq 1 ]; then
            echo "$final_query" >> "$history_file"
            echo "$cmd1"
            rm -f "$res_file"
            return 0
        fi

        # 5. 다중 후보군 FZF 선택창 구성
        local menu_input=""
        # UX 보강 3: 숫자 키 필터링 단축 선택을 위해 1., 2., 3. 라벨 부여
        [ -n "$cmd1" ] && menu_input="${menu_input}👉 1. $cmd1  ($desc1)\n"
        [ -n "$cmd2" ] && menu_input="${menu_input}👉 2. $cmd2  ($desc2)\n"
        [ -n "$cmd3" ] && menu_input="${menu_input}👉 3. $cmd3  ($desc3)\n"
        menu_input="${menu_input}🔍 질의어 수정 후 재시도\n❌ 취소"

        local selected_option
        selected_option=$(printf "$menu_input" | fzf \
            --height 12 \
            --layout=reverse \
            --header "🤖 ctrlg 추천 명령어 선택 (숫자 입력 또는 방향키 이동)")

        local menu_status=$?
        rm -f "$res_file"

        # 사용자가 취소(Esc/Ctrl+C)한 경우
        if [ $menu_status -ne 0 ] || [[ "$selected_option" == "❌ 취소" ]]; then
            return 1
        fi

        # 결과 분기 처리
        if [[ "$selected_option" == "🔍 질의어 수정 후 재시도" ]]; then
            # 질의를 수정할 수 있도록 루프를 계속하되, 이번에는 직접 입력받도록 플래그 설정
            show_history_prompt=false
            current_query="$final_query"
            continue
        elif [[ "$selected_option" == *"1. "* ]]; then
            echo "$final_query" >> "$history_file"
            echo "$cmd1"
            return 0
        elif [[ "$selected_option" == *"2. "* ]]; then
            echo "$final_query" >> "$history_file"
            echo "$cmd2"
            return 0
        elif [[ "$selected_option" == *"3. "* ]]; then
            echo "$final_query" >> "$history_file"
            echo "$cmd3"
            return 0
        fi
    done
}
