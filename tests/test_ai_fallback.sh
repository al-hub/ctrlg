#!/usr/bin/env bash

# AI Fallback 타임아웃 무한 대기(Hang) 검출 테스트
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 존재하지 않는 사설 IP 주소 (RFC 5737에 따른 테스트 전용 대역)
# 이 IP 주소로 통신을 시도하면 라우팅이 불가능하여 타임아웃 대기(Hang) 상태가 유발됩니다.
TEST_DUMMY_HOST="http://192.0.2.1:11434"

echo "🧪 [TDD 테스트] Ollama 호스트 무반응 대기(Hang) 강제 검출 시도..."

# 임시 환경변수로 OLLAMA_HOST를 무반응 IP로 세팅
export OLLAMA_HOST="$TEST_DUMMY_HOST"

# 4초 타임아웃 제어 하에 ctrlg 호출
# 만약 ctrlg 내부 curl에 타임아웃 제어 장치가 없다면, 4초 동안 응답하지 못하고 timeout 명령어에 의해 강제 종료(Exit Code 124)될 것입니다.
# 만약 내부에서 빠르게 타임아웃을 먹고 에러를 내며 탈출했다면 exit code는 124가 아닐 것입니다.
timeout 4s /home/al-hub/workspace/ctrlg/bin/ctrlg --raw "하위폴더갯수"
status=$?

if [ $status -eq 124 ]; then
    echo "❌ [검출 완료] 서버가 무반응일 때, ctrlg가 무한 대기(Hang)에 빠지는 버그가 발견되었습니다!"
    exit 1
else
    echo "✅ [정상] 무반응 서버에 대해 적절한 타임아웃 처리로 즉시 탈출 완료 (종료 코드: $status)"
    exit 0
fi
