#!/usr/bin/env bash

# UI 위젯 구조 검증 TDD 테스트
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🧪 [TDD Test] install.sh가 생성하는 쉘 위젯에 필수 구조가 포함되어 있는지 검증..."

# 가상의 프로필 파일로 주입 테스트
MOCK_BASHRC="/tmp/mock_bashrc_ui"
echo "# Mock" > "$MOCK_BASHRC"

# install.sh를 구동하여 가상 파일에 설정을 주입시킵니다.
source "${PROJECT_DIR}/install.sh" &>/dev/null
inject_shell_profile "bash" "$MOCK_BASHRC" &>/dev/null

# 주입된 결과 파일 내용 읽기
injected_content=$(cat "$MOCK_BASHRC")

# 1. 쉘 위젯 로딩 및 자연어 보존을 위한 개행 제어 코드가 주입되어 있는지 단언
if [[ "$injected_content" != *'printf'* ]]; then
    echo "❌ [FAIL] 자연어 질의 보존 및 로그 출력을 위한 화면 제어 코드(printf)가 주입 코드 내에 누락되었습니다!"
    rm -f "$MOCK_BASHRC"
    exit 1
fi

# 2. ctrlg --raw 호출이 주입되어 있는지 단언
if [[ "$injected_content" != *"--raw"* ]]; then
    echo "❌ [FAIL] ctrlg --raw 호출 코드가 주입 코드 내에 누락되었습니다!"
    rm -f "$MOCK_BASHRC"
    exit 1
fi

echo "✅ [PASS] install.sh의 쉘 위젯 템플릿 내 필수 구조 검증 성공!"
rm -f "$MOCK_BASHRC"
exit 0
