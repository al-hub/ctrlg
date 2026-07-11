#!/usr/bin/env bash

# UI 실시간 피드백 및 ANSI 화면 제어 코드 검증 TDD 테스트
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🧪 [TDD Test] install.sh가 생성하는 쉘 위젯에 UI 실시간 피드백 코드(\e[1A\e[2K)가 포함되어 있는지 검증..."

# 가상의 프로필 파일로 주입 테스트
MOCK_BASHRC="/tmp/mock_bashrc_ui"
echo "# Mock" > "$MOCK_BASHRC"

# install.sh를 구동하여 가상 파일에 설정을 주입시킵니다.
# (install.sh가 갱신되어 이 피드백을 지원하는지 검증하기 위함)
source "${PROJECT_DIR}/install.sh" &>/dev/null
inject_shell_profile "bash" "$MOCK_BASHRC" &>/dev/null

# 주입된 결과 파일 내용 읽기
injected_content=$(cat "$MOCK_BASHRC")

# 1. 쉘 위젯 로딩을 위한 단일 개행이 스니펫에 주입되어 있는지 단언 (1행 스트리밍 연출 공간 확보)
if [[ "$injected_content" != *"printf \"\\\\n\""* ]]; then
    echo "❌ [FAIL] 단축키 동작 과정 실시간 갱신을 위한 개행 확보 코드가 쉘 프로필 주입 코드 내에 누락되었습니다!"
    rm -f "$MOCK_BASHRC"
    exit 1
fi

# 2. ANSI 터미널 렌더링 지우기 및 복구 코드가 주입되어 있는지 단언
if [[ "$injected_content" != *"1A"* ]] || [[ "$injected_content" != *"2K"* ]]; then
    echo "❌ [FAIL] 로딩 종료 후 화면 복구를 위한 ANSI 커서 제어 코드(\\e[1A\\e[2K)가 주입 코드 내에 누락되었습니다!"
    rm -f "$MOCK_BASHRC"
    exit 1
fi

echo "✅ [PASS] install.sh의 쉘 위젯 템플릿 내 실시간 피드백 검증 성공!"
rm -f "$MOCK_BASHRC"
exit 0
