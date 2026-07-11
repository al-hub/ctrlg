#!/usr/bin/env bash

# ctrlg 대화형 (Interactive) FZF 모드 모듈
# 모든 UI 출력 및 로그는 stderr로 보내고, 최종 선택된 명령어만 stdout으로 출력합니다.

run_interactive_mode() {
    local query="$1"
    local initial_query="$query"
    
    # fzf 존재 여부 확인
    if ! command -v fzf &>/dev/null; then
        echo "❌ [오류] 대화형 모드를 사용하려면 'fzf'가 설치되어 있어야 합니다." >&2
        return 1
    fi

    while true; do
        # 1. 질의어 입력/수정 창 띄우기 (fzf --print-query 활용)
        # </dev/tty를 통해 터미널 키 입력을 명시적으로 획득합니다.
        local fzf_out
        fzf_out=$(printf "입력을 완료하고 Enter를 누르세요" | fzf \
            --height 10 \
            --layout=reverse \
            --header "🤖 ctrlg: 자연어로 명령어를 입력하세요 (Esc로 취소)" \
            --query "$initial_query" \
            --print-query \
            </dev/tty)
            
        # fzf 종료 상태코드 확인 (Esc 누르면 130 반환)
        local fzf_status=$?
        if [ $fzf_status -ne 0 ] && [ -z "$fzf_out" ]; then
            return 1
        fi

        # fzf_out의 첫 번째 라인이 사용자가 입력한 query입니다.
        query=$(echo "$fzf_out" | head -n 1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        
        if [ -z "$query" ]; then
            echo "⚠️  입력된 질의어가 없어 취소합니다." >&2
            return 1
        fi

        echo "" >&2
        echo "🤖 AI 추천 명령어를 생성하는 중..." >&2
        
        # 2. AI 호출 (Stderr는 화면에 실시간 노출, 최종 명령어만 res_file에 저장)
        local res_file=$(mktemp)
        "${PROJECT_DIR}/bin/ctrlg" --raw "$query" > "$res_file"
        
        local recommended_cmd=$(cat "$res_file" | xargs)
        rm -f "$res_file"

        # AI 결과가 없는 경우 처리
        if [ -z "$recommended_cmd" ]; then
            echo "❌ 추천 명령어를 생성하지 못했습니다. 질의어를 수정해 주세요." >&2
            initial_query="$query"
            sleep 1.5
            continue
        fi

        echo "" >&2
        echo "✨ 추천 명령어 생성 완료!" >&2

        # 3. 명령어 적용/수정/취소 선택 창
        local choice
        choice=$(printf "👉 명령어 적용: %s\n🔍 질의어 수정 후 재시도\n❌ 취소" "$recommended_cmd" | fzf \
            --height 10 \
            --layout=reverse \
            --header "선택된 명령어 적용 여부 결정" \
            </dev/tty)

        if [[ "$choice" == "👉 명령어 적용:"* ]]; then
            # 최종 명령어를 stdout으로 출력하고 정상 종료
            echo "$recommended_cmd"
            return 0
        elif [[ "$choice" == *"질의어 수정 후 재시도" ]]; then
            # 수정을 위해 질의어를 유지하고 루프로 돌아감
            initial_query="$query"
            continue
        else
            # 취소 시 원래 질의어로 복귀할 수 있도록 빈 값으로 리턴
            return 1
        fi
    done
}
