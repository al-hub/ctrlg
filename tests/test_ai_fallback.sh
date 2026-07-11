#!/usr/bin/env bash

# AI Fallback 타임아웃 무한 대기(Hang) 및 성공적 변환 무결성 TDD 검증
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ==========================================
# Test 1: 무반응 호스트 대기(Hang) 감지 테스트
# ==========================================
TEST_DUMMY_HOST="http://192.0.2.1:11434"
echo "🧪 [TDD Test 1] Ollama 호스트 무반응 대기(Hang) 감지 시도..."
export OLLAMA_HOST="$TEST_DUMMY_HOST"

# 7초 타임아웃 제어 하에 ctrlg 호출
# (동적 헬스체크 0.5초*2회 + 실제 통신 타임아웃 3초의 최대 지연 누적분을 감안하여 7초 내에 최종 탈출하는지 확인)
timeout 7s /home/al-hub/workspace/ctrlg/bin/ctrlg --raw "하위폴더갯수"
status=$?

if [ $status -eq 124 ]; then
    echo "❌ [Test 1 FAIL] 서버 무반응 시 무한 대기에 빠지는 버그가 발견되었습니다!"
    exit 1
fi
echo "✅ [Test 1 PASS] 무반응 서버에 대해 대기하지 않고 즉시 탈출 완료"


# ==========================================
# Test 2: 정상 서버 가동 환경에서의 실제 치환 성공 검증
# ==========================================
echo "🧪 [TDD Test 2] 정상 Ollama 환경에서의 명령어 치환 성공 여부 검증..."

# 로컬 Ollama 헬스체크 (정상적으로 떠있는지 확인)
# 127.0.0.1:11434 포트가 켜져 있는지 검사합니다.
curl -s --connect-timeout 2 http://127.0.0.1:11434/api/tags &>/dev/null
if [ $? -ne 0 ]; then
    echo "⚠️  [Test 2 SKIP] 로컬 Ollama 서버(127.0.0.1:11434)가 꺼져 있어 성공 테스트를 건너뜁니다."
    exit 0
fi

# 정상 로컬 호스트로 복구 설정
export OLLAMA_HOST="http://127.0.0.1:11434"

# 치환 가동
result=$(/home/al-hub/workspace/ctrlg/bin/ctrlg --raw "하위폴더갯수")

if [[ "$result" == *"find"* ]]; then
    echo "✅ [Test 2 PASS] 명령어 치환 성공: '$result'"
else
    echo "❌ [Test 2 FAIL] 실제 AI 치환이 작동하지 않고 원본이 유지되었습니다! 결과: '$result'"
    exit 1
fi

# ==========================================
# Test 3: 복잡한 날짜 자연어 조건문의 치환 성공 검증 (TDD 추가)
# ==========================================
echo "🧪 [TDD Test 3] 복잡한 날짜 쿼리에 대한 치환 성공 및 보안 통과 검증..."
result_complex=$(/home/al-hub/workspace/ctrlg/bin/ctrlg --raw "2026 4월 20일 이전의 생성된 파일의 갯수와 파일명")

if [[ "$result_complex" == *"find"* ]] && [[ "$result_complex" == *"newermt"* ]]; then
    echo "✅ [Test 3 PASS] 복잡 날짜 쿼리 치환 성공: '$result_complex'"
    exit 0
else
    echo "❌ [Test 3 FAIL] 날짜 쿼리 치환 실패 또는 보안 차단 발생! 결과: '$result_complex'"
    exit 1
fi
