#!/usr/bin/env bash

# 범용 매트릭스 기반 명령어 치환 다차원 검증 TDD
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🧪 [TDD Matrix Test] 범용 질의-답변 테이블 기반 치환 검증..."

# 1. Ollama 가동 체크
curl -s --connect-timeout 2 http://127.0.0.1:11434/api/tags &>/dev/null
if [ $? -ne 0 ]; then
    echo "⚠️  [SKIP] 로컬 Ollama 서버가 동작하지 않아 매트릭스 테스트를 스킵합니다."
    exit 0
fi

# 2. 테스트 매트릭스 데이터셋 선언
# 형식 -> "자연어질의 : 필수포함단어1 : 필수포함단어2 : 불허단어"
# 추후 새 질의를 검증할 때 이 배열에 문자열 한 줄만 덧붙이면 즉시 범용 검사가 진행됩니다.
TEST_CASES=(
    "하위폴더 중 *.zip 확장자의 파일목록과 갯수:find:zip:ls"
)

failed=0

for tc in "${TEST_CASES[@]}"; do
    # 구분자 ':' 로 데이터 분해
    IFS=":" read -r query must1 must2 forbidden <<< "$tc"
    
    echo "   - 실행 질의: '$query'"
    
    # 치환 구동 (콜드 스타트 방어 55초 제한)
    result=$(timeout 55s /home/al-hub/workspace/ctrlg/bin/ctrlg --raw "$query")
    
    # 단언 검증 (Assert)
    local_fail=0
    
    # 필수 포함 단어 검사
    if [[ "$result" != *"$must1"* ]] || [[ "$result" != *"$must2"* ]]; then
        echo "     ❌ [FAIL] 필수 검증 단어 누락 (기대 키워드: '$must1' 및 '$must2')"
        local_fail=1
    fi
    
    # 불허 단어 오답 검사
    if [[ -n "$forbidden" ]] && [[ "$result" == *"$forbidden"* ]]; then
        echo "     ❌ [FAIL] 부적합 명령어 오탐지 발생 (금지 키워드: '$forbidden')"
        local_fail=1
    fi
    
    if [ $local_fail -eq 0 ]; then
        echo "     ✅ [PASS] 정상 치환 통과: '$result'"
    else
        echo "     🚨 오작동 출력물: '$result'"
        failed=1
    fi
done

if [ $failed -eq 0 ]; then
    exit 0
else
    exit 1
fi
