#!/usr/bin/env bash

# 실시간 단계별 진행 피드백(UX) 출력 여부를 검증하는 TDD 테스트
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🧪 [TDD Test] 실시간 진행 과정 피드백(Stderr 스트리밍) 갱신 무결성 검증..."

# 1. Ollama 가동 체크
curl -s --connect-timeout 2 http://127.0.0.1:11434/api/tags &>/dev/null
if [ $? -ne 0 ]; then
    echo "⚠️  [SKIP] 로컬 Ollama 서버가 동작하지 않아 실시간 피드백 테스트를 스킵합니다."
    exit 0
fi

# 2. ctrlg 구동 시 Stderr 출력 스트림을 캡처 파일로 저장
stderr_log="${PROJECT_DIR}/scratch/stderr_progress.log"
mkdir -p "$(dirname "$stderr_log")"
rm -f "$stderr_log"

# --raw 질의를 날리면서 표준 에러(2)만 로그 파일로 가로챕니다.
/home/al-hub/workspace/ctrlg/bin/ctrlg --raw "하위폴더갯수" 2> "$stderr_log" >/dev/null

echo "   - 캡처된 Stderr 진행 로그 내용 분석 중..."

# 3. 단언 검증 (Assert)
# 사용자의 대기 피로도를 없애기 위해 Stderr에 실시간 진행 정보가 갱신 출력되었는지 확인합니다.
errors=0

check_step() {
    local keyword="$1"
    local step_desc="$2"
    if grep -q "$keyword" "$stderr_log"; then
        echo "     ✅ [OK] 단계 감지 성공: $step_desc"
    else
        echo "     ❌ [FAIL] 단계 누락: $step_desc ('$keyword' 문구가 Stderr 로그에 발견되지 않음)"
        errors=$((errors + 1))
    fi
}

check_step "host" "1단계 (Ollama 호스트 탐색 및 연결)"
check_step "model" "2단계 (AI 모델 및 추론 실행)"
check_step "security" "3단계 (보안성 검증)"

# 4. 최종 결과 판정
if [ $errors -eq 0 ]; then
    echo "✅ [TDD PASS] 실시간 단계별 피드백 스트리밍이 완벽하게 가동 중입니다."
    rm -f "$stderr_log"
    exit 0
else
    echo "❌ [TDD FAIL] 실시간 과정 피드백 중 일부 마일스톤 출력이 누락되어 있습니다!"
    echo "   - [디버그용] 실제 출력된 Stderr 로그:"
    cat "$stderr_log"
    rm -f "$stderr_log"
    exit 1
fi
