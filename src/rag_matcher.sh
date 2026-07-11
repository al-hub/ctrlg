#!/usr/bin/env bash

# RAG용 tldr 컨텍스트 파서
get_tldr_context() {
    local query="$1"
    local project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local tldr_path="${project_dir}/resources/tldr"
    
    # 입력어에서 특수기호나 단어를 분리하여 매칭되는 가이드북을 찾음
    for word in $query; do
        # 소문자 변환 및 문자열 정제
        local lower_word=$(echo "$word" | tr '[:upper:]' '[:lower:]' | tr -d '.-')
        if [ -n "$lower_word" ] && [ -f "${tldr_path}/${lower_word}.md" ]; then
            # RAG 컨텍스트로 사용하기 위해 가이드의 앞부분 25줄을 반환
            cat "${tldr_path}/${lower_word}.md" | head -n 25
            return 0
        fi
    done
    return 1
}
