#!/usr/bin/env bash

# 명령어 보안 검증 모듈
# 안전하면 0 리턴, 위험하면 1 리턴
validate_command() {
    local cmd="$1"
    local whitelist="$2"

    # 1단계: 위험한 핵심 쉘 인젝션/삭제 패턴 차단
    if echo "$cmd" | grep -qE 'rm|dd|mv|:|;|sudo|/etc/|sh -c|&|`|\$\(|>'; then
        return 1
    fi

    # 2단계: 파이프라인 개별 분해 검증
    local valid=1
    while read -r sub_cmd; do
        [ -z "$sub_cmd" ] && continue
        sub_cmd=$(echo "$sub_cmd" | xargs)
        local sub_base=$(echo "$sub_cmd" | awk '{print $1}')
        
        local matched=0
        for w in $whitelist; do
            if [ "$sub_base" = "$w" ]; then
                matched=1
                break
            fi
        done
        
        if [ $matched -eq 0 ]; then
            valid=0
            break
        fi
    done <<< "$(echo "$cmd" | tr '|' '\n')"

    if [ $valid -eq 1 ]; then
        return 0
    else
        return 2 # 허용되지 않은 유틸리티 에러 코드
    fi
}
