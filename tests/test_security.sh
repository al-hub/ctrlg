#!/usr/bin/env bash

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${PROJECT_DIR}/src/security.sh"

# Assert Helper
assert_status() {
    local cmd="$1"
    local expected_status="$2"
    local whitelist="ls pwd df du date whoami ps free hostname cat grep find uname echo head tail wc awk xargs"
    
    validate_command "$cmd" "$whitelist"
    local actual_status=$?
    if [ "$actual_status" -ne "$expected_status" ]; then
        echo -e "\n   ❌ Command: '$cmd' -> Expected Status: $expected_status, but got: $actual_status"
        exit 1
    fi
}

# Test Cases
# 1. 안전한 명령어 통과 (0)
assert_status "ls -la" 0

# 2. 위험 명령어 즉각 차단 (1)
assert_status "rm -rf /" 1
assert_status "sudo apt update" 1
assert_status "ls; rm -rf ." 1

# 3. 허용되지 않은 명령어 통제 (2)
assert_status "docker ps" 2

# 4. 파이프라인 안전 결합 허용 (0)
assert_status "find . -type f | wc -l" 0

# 5. 파이프라인 악성 결합 통제 (1 또는 2)
assert_status "find . -type f | rm -rf" 1

exit 0
