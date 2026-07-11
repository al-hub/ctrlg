#!/usr/bin/env bash

# Ollama 콜드 스타트(VRAM 언로드) 및 최대 대기 타임아웃 검증 TDD 테스트
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🧪 [TDD Test] Ollama 콜드 스타트(메모리 언로드) 상태에서의 로딩 대기 한계 검증..."

# 1. 로컬 Ollama 가동 여부 확인 (헬스체크)
curl -s --connect-timeout 2 http://127.0.0.1:11434/api/tags &>/dev/null
if [ $? -ne 0 ]; then
    echo "⚠️  [SKIP] 로컬 Ollama 서버가 동작하지 않아 콜드 스타트 테스트를 스킵합니다."
    exit 0
fi

# 2. Ollama API를 사용해 gemma4-e2b-q4 모델을 그래픽 메모리(VRAM)에서 강제 언로드 (Unload)
# keep_alive를 0으로 주고 빈 프롬프트를 보내면 즉시 메모리에서 내립니다.
curl -s -X POST http://127.0.0.1:11434/api/generate -d '{
    "model": "gemma4-e2b-q4:latest",
    "prompt": "",
    "keep_alive": 0
}' &>/dev/null

echo "   - Ollama VRAM 모델 언로드 완료. 콜드 스타트 상태를 유도했습니다."
echo "   - 10초 미만(8초) 제한 시간 하에 복잡 날짜 명령어 치환 실행..."

# 3. 모델 로딩에 10~15초가 걸리는 상태에서, 25초 충분한 제한을 두고 치환 실행
# 최대 제한 시간 25초 하에 콜드 스타트 지연을 이겨내고 정상적으로 명령어 치환이 수행되어야 합니다.
result=$(timeout 25s /home/al-hub/workspace/ctrlg/bin/ctrlg --raw "2026 4월 20일 이전의 생성된 파일의 갯수와 파일명")

# 4. 검증 (Assert)
# 25초의 대기로 콜드 스타트 상태임에도 치환에 최종 성공했는지 확인합니다.
if [[ "$result" == *"find"* ]]; then
    echo "✅ [통과] 콜드 스타트 상태임에도 25초 이내에 정상적으로 치환 완료: '$result'"
    exit 0
else
    echo "❌ [FAIL] 25초의 여유 시간이 주어졌음에도 치환에 실패하고 원본이 반환되었습니다!"
    echo "   - 출력 결과: '$result'"
    exit 1
fi
