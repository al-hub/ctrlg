#!/usr/bin/env bash

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${PROJECT_DIR}/src/fast_path.sh"

# Assert Helper
assert_equals() {
    local expected="$1"
    local actual="$2"
    if [ "$expected" != "$actual" ]; then
        echo -e "\n   ❌ Expected: '$expected', but got: '$actual'"
        exit 1
    fi
}

# Test Cases
# 1. 현재위치 매핑
cmd=$(check_fast_path "현재위치")
assert_equals "pwd" "$cmd"

# 2. 하위목록 매핑
cmd=$(check_fast_path "하위목록")
assert_equals "ls -la" "$cmd"

# 3. 미일치 단어는 1 리턴해야 함
check_fast_path "일반질문"
if [ $? -ne 1 ]; then
    echo "❌ 미일치 단어 리턴 코드 에러"
    exit 1
fi

exit 0
