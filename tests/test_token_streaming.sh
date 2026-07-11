#!/usr/bin/env bash

# AI 명령어 생성 실시간 토큰 스트리밍(Streaming UX) 작동 여부를 검증하는 TDD 테스트
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🧪 [TDD Test] AI 추천 명령어 실시간 한 글자씩 스트리밍(Token Streaming) UX 검증..."

# 1. Ollama 가동 체크
curl -s --connect-timeout 2 http://127.0.0.1:11434/api/tags &>/dev/null
if [ $? -ne 0 ]; then
    echo "⚠️  [SKIP] 로컬 Ollama 서버가 동작하지 않아 스트리밍 테스트를 스킵합니다."
    exit 0
fi

# 2. ctrlg 구동 시 Stderr 출력 스트림을 캡처 파일로 저장
stderr_log="${PROJECT_DIR}/scratch/stderr_stream.log"
mkdir -p "$(dirname "$stderr_log")"
rm -f "$stderr_log"

# --raw 질의를 날리면서 표준 에러(2)만 로그 파일로 가로챕니다.
/home/al-hub/workspace/ctrlg/bin/ctrlg --raw "하위폴더 중 *.zip 확장자의 파일목록과 갯수" 2> "$stderr_log" >/dev/null

echo "   - 캡처된 Stderr 실시간 스트리밍 로그 분석 중..."

# 3. 단언 검증 (Assert)
errors=0
if grep -q "ref   :" "$stderr_log"; then
    echo "     ✅ [OK] RAG 예시 명령어 누적 로그 출력 감지 성공"
else
    echo "     ❌ [FAIL] RAG 예시 명령어 로그(ref   :)가 Stderr 로그에 없습니다."
    errors=$((errors + 1))
fi

if grep -q "output:" "$stderr_log"; then
    echo "     ✅ [OK] AI 실시간 생성 출력 로그 접두사 감지 성공"
else
    echo "     ❌ [FAIL] AI 출력 로그 접두사('output:')가 Stderr 로그에 없습니다."
    errors=$((errors + 1))
fi

# 누적 스트림 흔적 검사 (find 명령어의 점진적인 조각들이 Stderr에 이어서 기록되었는지 확인)
if grep -q "find" "$stderr_log" && grep -q "wc" "$stderr_log"; then
    echo "     ✅ [OK] 실시간 명령어 단어(find, wc) 추출 및 스트리밍 흔적 검사 성공"
else
    echo "     ❌ [FAIL] 생성 토큰(find, wc) 스트리밍 흔적이 로그에서 누락되었습니다."
    errors=$((errors + 1))
fi

# 4. 최종 결과 판정
if [ $errors -eq 0 ]; then
    echo "✅ [TDD PASS] AI 추천 명령어 실시간 한 글자씩 스트리밍(Token Streaming) UX 검증 완료."
    rm -f "$stderr_log"
    exit 0
else
    echo "❌ [TDD FAIL] 실시간 토큰 스트리밍 UX 중 일부 구성요소가 오작동했습니다!"
    echo "     - [디버그용] 실제 출력된 Stderr 로그:"
    cat "$stderr_log"
    rm -f "$stderr_log"
    exit 1
fi
