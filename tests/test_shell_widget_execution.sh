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
# 이 함수의 이스케이프 및 printf 화면 지우기 처리가 100% 정상 작동하며 결과물을 교체하는지 검증합니다.
_test_bash_bind_widget() {
    # 사용자 입력어 정의 (실제 쉘 입력창 상태 모방)
    READLINE_LINE="2026 4월 20일 이전의 생성된 파일의 갯수와 파일명"
    READLINE_POINT=${#READLINE_LINE}
    
    # install.sh에 등록된 것과 100% 동일한 위젯 로직 수행
    local query="$READLINE_LINE"
    if [ -n "$query" ]; then
        # 단일 개행으로 실시간 Stderr 렌더링 영역을 확보
        printf "\n"
        
        # 실제 빌드 주소의 바이너리를 사용해 원시 쿼리 획득
        local result=$(${PROJECT_DIR}/bin/ctrlg --raw "$query")
        
        # 화면 복구를 위한 1행 지우기 시퀀스
        printf "\e[1A\e[2K"
        
        # 쉘 버퍼 교체
        READLINE_LINE="$result"
        READLINE_POINT=${#READLINE_LINE}
    fi
    
    # 최종 결과물 리턴
    echo "$READLINE_LINE"
}

# 3. 위젯 구동 및 결과 캡처
# 25초 넉넉한 시간 제한을 걸어 콜드 스타트에 의한 지연을 방어합니다.
widget_result=$(timeout 25s bash -c "$(declare -f _test_bash_bind_widget); PROJECT_DIR=$PROJECT_DIR; _test_bash_bind_widget")

# 4. 검증 (Assert)
# 만약 실제 위젯 환경 내부에서 통신 오류나 치환 실패가 나고
# 원본 자연어 텍스트가 그대로 복원(유지)되어 반환되었다면 실패(FAIL) 처리합니다.
if [[ "$widget_result" != *"find"* ]]; then
    echo "❌ [검출 완료] 쉘 위젯 구동 시 치환이 정상 수행되지 못하고 원본 텍스트로 복원(유지)되었습니다!"
    echo "   - 복원된 결과물: '$widget_result'"
    exit 1
else
    echo "✅ [PASS] 쉘 위젯 구동 및 치환 결과 검증 성공: '$widget_result'"
    exit 0
fi
