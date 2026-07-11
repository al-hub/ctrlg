#!/usr/bin/env bash

# 인스톨러 및 쉘 프로필 구문 오류(Syntax Error) 검증 테스트
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 임시 테스트용 가상 프로필 파일 생성
MOCK_BASHRC="/tmp/mock_bashrc"
echo "# Mock Bashrc File for testing" > "$MOCK_BASHRC"
echo "alias ll='ls -al'" >> "$MOCK_BASHRC"

# install.sh 로딩하여 환경 테스트
# install.sh 내부의 inject_shell_profile 함수를 추출하거나 직접 테스트하기 위해
# install.sh에 정의된 주입 로직을 시뮬레이션합니다.
BIN_DEST="$HOME/.local/bin/ctrlg"

simulate_inject() {
    local profile_path="$1"
    local snippet="
# ctrlg AI CLI Integration Start
if [ -f ${BIN_DEST} ]; then
    _ctrlg_bash_bind() {
        local query=\"\$READLINE_LINE\"
        if [ -n \"\$query\" ]; then
            local result=\$(\$HOME/.local/bin/ctrlg --raw \"\$query\")
            READLINE_LINE=\"\$result\"
            READLINE_POINT=\$\{#READLINE_LINE\}
        fi
    }
    bind -x '\"\C-g\": _ctrlg_bash_bind'

    ctrlg_error_hook() {
        local last_exit=\$?
        local last_cmd=\$(history 1 | sed 's/^[ ]*[0-9]*[ ]*//')
        if [ \$last_exit -ne 0 ] && [[ \"\$last_cmd\" != ctrlg* ]] && [[ \"\$last_cmd\" != cg* ]]; then
            \$HOME/.local/bin/ctrlg --analyze-error \"\$last_cmd\" \$last_exit
        fi
    }
    PROMPT_COMMAND=\"ctrlg_error_hook; \$PROMPT_COMMAND\"
fi
# ctrlg AI CLI Integration End"

    # 중복 삭제 로직 작동 시뮬레이션
    if grep -q "# ctrlg AI CLI Integration" "$profile_path"; then
        # 이전 구버전 방식 및 신버전 마커 방식 모두 제거 테스트
        sed -i '/# ctrlg AI CLI Integration Start/,/# ctrlg AI CLI Integration End/d' "$profile_path"
        sed -i '/# ctrlg AI CLI Integration/,/fi/d' "$profile_path" 2>/dev/null
        # 연속된 빈 줄 정리
        sed -i '/^$/N;/^\n$/D' "$profile_path"
    fi

    # 스니펫 주입
    echo "$snippet" >> "$profile_path"
}

echo "   1. 1차 주입 테스트 실행..."
simulate_inject "$MOCK_BASHRC"

# 1차 문법 검사 (bash -n 은 실행 없이 문법적 결함만 감지함)
bash -n "$MOCK_BASHRC"
if [ $? -ne 0 ]; then
    echo "❌ 1차 주입 후 bashrc 문법 오류 감지됨"
    rm -f "$MOCK_BASHRC"
    exit 1
fi

echo "   2. 2차 (중복/업데이트) 주입 및 삭제 테스트 실행..."
simulate_inject "$MOCK_BASHRC"

# 2차 문법 검사 (이전 찌꺼기가 꼬여서 syntax error를 발생시키는지 검증)
bash -n "$MOCK_BASHRC"
if [ $? -ne 0 ]; then
    echo "❌ 2차 (업데이트) 주입 후 bashrc 문법 오류 감지됨 (중복 삭제 오작동)"
    rm -f "$MOCK_BASHRC"
    exit 1
fi

# 가상 파일 정리
rm -f "$MOCK_BASHRC"
exit 0
