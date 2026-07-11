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

# 3. 모델 로딩에 10~15초가 걸리는 상태에서, 8초 제한을 두고 치환 실행
# 내부 curl의 최대 제한 시간(--max-time 10) 또는 8초 제한으로 인해
# 콜드 스타트 첫 가동은 8초 내에 끝나지 못하고 치환 실패(원본 '2026 4월...' 리턴)가 일어나야 합니다.
result=$(timeout 8s /home/al-hub/workspace/ctrlg/bin/ctrlg --raw "2026 4월 20일 이전의 생성된 파일의 갯수와 파일명")

# 4. 검증 (Assert)
# 원래는 20초 이상의 충분한 대기로 변환에 성공해야 정상이나,
# 현재 코드 스펙상 8초(또는 10초) 한계로 인해 실패하여 원본 텍스트가 그대로 출력되는 현상을 TDD로 검출합니다.
if [[ "$result" != *"find"* ]]; then
    echo "❌ [검출 완료] 콜드 스타트 시 모델 로딩 지연으로 인해 치환에 실패하고 원본이 반환되었습니다!"
    echo "   - 출력 결과: '$result'"
    # 이 실패 현상을 TDD상으로 발굴/증명(Exit Code 1)하기 위해 실패 처리합니다.
    exit 1
else
    echo "✅ [통과] 콜드 스타트 상태임에도 8초 이내에 빠르게 치환 완료: '$result'"
    exit 0
fi
