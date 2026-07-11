#!/usr/bin/env bash

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DEST="$HOME/.local/bin/ctrlg"
ALIAS_DEST="$HOME/.local/bin/cg"

echo "⚙️  ctrlg (AI CLI Helper) 설치를 시작합니다..."

# 의존성 체크
for cmd in curl jq perl; do
    if ! command -v $cmd &>/dev/null; then
        echo "⚠️  의존성 오류: '$cmd' 패키지가 설치되어 있지 않습니다."
        echo "설치 후 다시 시도해 주세요. (예: sudo apt install $cmd)"
        exit 1
    fi
done

# 실행 권한 부여
chmod +x "${PROJECT_DIR}/bin/ctrlg"
chmod +x "${PROJECT_DIR}/src/"*.sh
chmod +x "${PROJECT_DIR}/tests/"*.sh

# ~/.local/bin 디렉토리 존재 확인
mkdir -p "$HOME/.local/bin"

# 심볼릭 링크 생성 (ctrlg와 cg 둘 다 생성)
for dest in "$BIN_DEST" "$ALIAS_DEST"; do
    if [ -L "$dest" ] || [ -f "$dest" ]; then
        rm -f "$dest"
    fi
    ln -s "${PROJECT_DIR}/bin/ctrlg" "$dest"
done

# 쉘 설정 결합 함수
inject_shell_profile() {
    local shell_name="$1"
    local profile_path="$2"
    local snippet=""

    if [ ! -f "$profile_path" ]; then
        return
    fi

    # 안전을 위한 백업 생성
    cp "$profile_path" "${profile_path}.bak_ctrlg"
    echo "💾 백업 생성 완료: ${profile_path}.bak_ctrlg"

    # 이미 설정이 삽입되어 있는지 체크하여 기존 블록 제거 (시작/끝 주석 기준 안전 삭제)
    if grep -q "# ctrlg AI CLI Integration" "$profile_path"; then
        # 구버전 fi 기반 제거 패턴과 신버전 Start/End 주석 제거 패턴 통합 적용
        sed -i '/# ctrlg AI CLI Integration Start/,/# ctrlg AI CLI Integration End/d' "$profile_path"
        sed -i '/# ctrlg AI CLI Integration/,/fi/d' "$profile_path" 2>/dev/null
        # 연속된 빈 줄 정리
        sed -i '/^$/N;/^\n$/D' "$profile_path"
    fi

    if [ "$shell_name" = "zsh" ]; then
        snippet="
# ctrlg AI CLI Integration Start
if [ -f ${BIN_DEST} ]; then
    # Zsh Ctrl+G 위젯 바인딩 (절대경로 및 실시간 피드백 적용)
    ctrlg-widget() {
        local query=\"\$BUFFER\"
        if [ -n \"\$query\" ]; then
            # 자연어 질의를 히스토리에 저장
            print -s \"\$query\"
            # 현재 줄을 주석으로 변경하여 화면에 남김
            printf \"\\\\r\\\\e[K# %s\\\\n\" \"\$query\"
            zle redisplay
            # AI 추천 명령어 획득 및 버퍼 대입
            local result=\$(${BIN_DEST} --raw \"\$query\")
            if [ -n \"\$result\" ]; then
                BUFFER=\"\$result\"
            else
                BUFFER=\"\$query\"
            fi
            CURSOR=\$\#BUFFER
            zle redisplay
        fi
    }
    zle -N ctrlg-widget
    bindkey '^g' ctrlg-widget

    # Zsh 에러 감지 훅
    ctrlg_error_hook() {
        local last_exit=\$?
        local last_cmd=\$(fc -ln -1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*\$//')
        if [ \$last_exit -ne 0 ] && [[ \"\$last_cmd\" != ctrlg* ]] && [[ \"\$last_cmd\" != cg* ]]; then
            ${BIN_DEST} --analyze-error \"\$last_cmd\" \$last_exit
        fi
    }
    # precmd_functions 배열에 에러 훅 추가
    typeset -ag precmd_functions
    if [[ \${precmd_functions[(r)ctrlg_error_hook]} != ctrlg_error_hook ]]; then
        precmd_functions+=(ctrlg_error_hook)
    fi
fi
# ctrlg AI CLI Integration End"
    elif [ "$shell_name" = "bash" ]; then
        snippet="
# ctrlg AI CLI Integration Start
if [ -f ${BIN_DEST} ]; then
    # Bash Ctrl+G 위젯 바인딩 (절대경로 및 실시간 피드백 적용)
    _ctrlg_bash_bind() {
        local query=\"\$READLINE_LINE\"
        if [ -n \"\$query\" ]; then
            # 자연어 질의를 히스토리에 저장
            history -s \"\$query\"
            # 현재 줄을 주석으로 변경하여 화면에 남김
            printf \"\\\\r\\\\e[K# %s\\\\n\" \"\$query\"
            # AI 추천 명령어 획득 및 버퍼 대입
            local result=\$(${BIN_DEST} --raw \"\$query\")
            if [ -n \"\$result\" ]; then
                READLINE_LINE=\"\$result\"
            else
                READLINE_LINE=\"\$query\"
            fi
            READLINE_POINT=\$\{#READLINE_LINE\}
        fi
    }
    bind -x '\"\C-g\": _ctrlg_bash_bind'

    # Bash 에러 감지 훅
    ctrlg_error_hook() {
        local last_exit=\$?
        local last_cmd=\$(history 1 | sed 's/^[ ]*[0-9]*[ ]*//')
        if [ \$last_exit -ne 0 ] && [[ \"\$last_cmd\" != ctrlg* ]] && [[ \"\$last_cmd\" != cg* ]]; then
            ${BIN_DEST} --analyze-error \"\$last_cmd\" \$last_exit
        fi
    }
    PROMPT_COMMAND=\"ctrlg_error_hook; \$PROMPT_COMMAND\"
fi
# ctrlg AI CLI Integration End"
    fi

    # 프로필 파일에 설정 덧붙이기
    echo "$snippet" >> "$profile_path"
    echo "✨ ${profile_path} 에 쉘 통합이 완료되었습니다."
}

# 쉘 설정 결합 가동
inject_shell_profile "zsh" "$HOME/.zshrc"
inject_shell_profile "bash" "$HOME/.bashrc"

echo "✅ 설치 및 쉘 통합 연동이 완료되었습니다!"
echo "새로운 터미널 세션을 열거나 'source ~/.bashrc' (또는 ~/.zshrc)를 가동하여 'ctrlg'를 활성화하세요."
