#!/usr/bin/env bash

# RAG용 tldr 컨텍스트 파서
get_tldr_context() {
    local query="$1"
    local project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local tldr_path="${project_dir}/resources/tldr"
    local context=""
    
    # 입력어에서 특수기호나 단어를 분리하여 매칭되는 가이드북을 찾음
    for word in $query; do
        # 소문자 변환 및 문자열 정제 (더 넓은 정제 필터링)
        local lower_word=$(echo "$word" | tr '[:upper:]' '[:lower:]' | tr -d '.-*?[]()"'\'')
        
        # 한글 유의어 기반 RAG 가이드 매칭 보정
        case "$lower_word" in
            하위폴더|디렉토리|검색|찾기|파일명|확장자)
                lower_word="find"
                ;;
            갯수|개수|라인수|라인|카운트)
                lower_word="wc"
                ;;
            압축|zip)
                lower_word="zip"
                ;;
        esac
        
        if [ -n "$lower_word" ] && [ -f "${tldr_path}/${lower_word}.md" ]; then
            # 중복 가이드 텍스트 삽입 방지 검사
            if [[ "$context" != *"$lower_word"* ]]; then
                context="${context}$(cat "${tldr_path}/${lower_word}.md" | head -n 25)$(printf "\n\n")"
            fi
        fi
    done
    
    if [ -n "$context" ]; then
        echo -e "$context"
        return 0
    else
        return 1
    fi
}
