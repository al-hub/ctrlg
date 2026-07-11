#!/usr/bin/env bash

# 테스트 러너 진입점
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="${PROJECT_DIR}/tests"

echo "========================================="
echo "🧪 ctrlg TDD 자동화 테스트 러너 가동"
echo "========================================="

PASSED=0
FAILED=0
TEST_FILES=$(find "$TEST_DIR" -name "test_*.sh")

for test_file in $TEST_FILES; do
    echo -n "🏃 Run $(basename "$test_file")... "
    bash "$test_file"
    if [ $? -eq 0 ]; then
        echo -e "[\e[1;32m PASS \e[0m]"
        PASSED=$((PASSED + 1))
    else
        echo -e "[\e[1;31m FAIL \e[0m]"
        FAILED=$((FAILED + 1))
    fi
done

echo "========================================="
echo "📊 테스트 요약 리포트"
echo "   - 성공(PASS): ${PASSED}"
echo "   - 실패(FAIL): ${FAILED}"
echo "========================================="

if [ $FAILED -ne 0 ]; then
    exit 1
fi
exit 0
