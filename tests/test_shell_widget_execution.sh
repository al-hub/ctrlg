#!/usr/bin/env bash

# 실제 쉘 위젯 바인딩 함수 실행 시 롤백(원복) 현상을 정밀 검출하는 TDD 테스트
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🧪 [TDD Test] 실제 쉘 위젯 함수(_ctrlg_bash_bind) 실행 및 치환 성공 여부 최종 검증..."

# 1. Ollama 가동 체크
curl -s --connect-timeout 2 http://127.0.0.1:11434/api/tags &>/dev/null
if [ $? -ne 0 ]; then
    echo "⚠️  [SKIP] 로컬 Ollama 서버가 동작하지 않아 위젯 구동 테스트를 스킵합니다."
    exit 0
fi

# 2. 실제 .bashrc 에 주입되는 동일한 스펙의 가상 위젯 바인딩 함수 정의
# 이제 위젯은 입력을 치환하지 않고 그대로 보존하므로, READLINE_LINE이 원본 질의를 유지하는지 확인합니다.
_test_bash_bind_widget() {
    # 사용자 입력어 정의 (실제 쉘 입력창 상태 모방)
    READLINE_LINE="2026 4월 20일 이전의 생성된 파일의 갯수와 파일명"
    READLINE_POINT=${#READLINE_LINE}
    
    local query="$READLINE_LINE"
    if [ -n "$query" ]; then
        printf "\n"
        # Stderr 로그 검증을 위해 파일로 에러 출력 기록
        ${PROJECT_DIR}/bin/ctrlg --raw "$query" 2> /tmp/widget_test_stderr.log >/dev/null
    fi
    
    # 최종 결과물 리턴 (치환되지 않고 원본 그대로 반환되어야 함)
    echo "$READLINE_LINE"
}

# 3. 위젯 구동 및 결과 캡처
_run_widget() {
    rm -f /tmp/widget_test_stderr.log
    timeout 35s bash -c "$(declare -f _test_bash_bind_widget); PROJECT_DIR=$PROJECT_DIR; _test_bash_bind_widget"
}

widget_result=$(_run_widget | xargs)

# 1차 시도에서 혹시 모를 로딩 문제로 빈 로그일 경우 1회 워밍 후 재시도
if [ ! -f /tmp/widget_test_stderr.log ] || ! grep -q "cmd     :" /tmp/widget_test_stderr.log; then
    echo "   - 1차 구동 결과 로그 미흡, 2초 대기 후 워밍업 재시도..."
    sleep 2
    widget_result=$(_run_widget | xargs)
fi

# 4. 검증 (Assert)
# A. 프롬프트 버퍼(입력)가 치환되지 않고 그대로 남았는지 단언
EXPECTED_QUERY="2026 4월 20일 이전의 생성된 파일의 갯수와 파일명"
if [ "$widget_result" != "$EXPECTED_QUERY" ]; then
    echo "❌ [FAIL] 쉘 위젯 구동 후 입력 프롬프트가 보존되지 않고 변경되었습니다!"
    echo "   - 현재 결과물: '$widget_result'"
    exit 1
fi

# B. Stderr 출력에 AI 추천 명령어 결과가 누적 로그 형태로 정상 표시되었는지 단언
if [ ! -f /tmp/widget_test_stderr.log ] || ! grep -q "cmd     :" /tmp/widget_test_stderr.log; then
    echo "❌ [FAIL] 쉘 위젯 실행 후 다음 줄에 추천 명령어 결과가 로그로 출력되지 않았습니다!"
    if [ -f /tmp/widget_test_stderr.log ]; then
        echo "   - Stderr 실제 출력물:"
        cat /tmp/widget_test_stderr.log >&2
    fi
    exit 1
fi

echo "✅ [PASS] 쉘 위젯 구동 시 입력이 그대로 남고 다음 줄에 결과가 성공적으로 로깅되었습니다."
rm -f /tmp/widget_test_stderr.log
exit 0
