#!/usr/bin/env bash

# AI Fallback 타임아웃 무한 대기(Hang) 및 성공적 변환 무결성 TDD 검증
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ==========================================
# Test 1: 무반응 호스트 대기(Hang) 감지 테스트
# ==========================================
TEST_DUMMY_HOST="http://192.0.2.1:11434"
echo "🧪 [TDD Test 1] Ollama 호스트 무반응 대기(Hang) 감지 시도..."
export OLLAMA_HOST="$TEST_DUMMY_HOST"

timeout 4s /home/al-hub/workspace/ctrlg/bin/ctrlg --raw "하위폴더갯수"
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

# 결과물 단언(Assert)
# '하위폴더갯수'에 대해 성공적으로 'find' 명령어가 도출되었는지 확인합니다.
# 만약 통신이 실패했거나 오작동하여 원본 문자열인 '하위폴더갯수'가 그대로 반환되었다면 테스트를 실패 처리합니다.
if [[ "$result" == *"find"* ]]; then
    echo "✅ [Test 2 PASS] 명령어 치환 성공: '$result'"
    exit 0
else
    echo "❌ [Test 2 FAIL] 실제 AI 치환이 작동하지 않고 원본이 유지되었습니다! 결과: '$result'"
    exit 1
fi
