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

    # 이미 설정이 삽입되어 있는지 체크
    if grep -q "# ctrlg AI CLI Integration" "$profile_path"; then
        echo "ℹ️  ${profile_path} 에 이미 ctrlg 쉘 통합 설정이 등록되어 있어 건너뜁니다."
        return
    fi

    # 안전을 위한 백업 생성
    cp "$profile_path" "${profile_path}.bak_ctrlg"
    echo "💾 백업 생성 완료: ${profile_path}.bak_ctrlg"

    if [ "$shell_name" = "zsh" ]; then
        snippet="
# ctrlg AI CLI Integration
if command -v ctrlg &>/dev/null; then
    # Zsh Ctrl+G 및 Ctrl+Space 위젯 바인딩
    ctrlg-widget() {
        local query=\"\$BUFFER\"
        if [ -n \"\$query\" ]; then
            POSTDISPLAY=\" ... (AI 분석 중)\"
            zle redisplay
            local result=\$(ctrlg --raw \"\$query\")
            BUFFER=\"\$result\"
            CURSOR=\$\#BUFFER
            POSTDISPLAY=\"\"
            zle redisplay
        fi
    }
    zle -N ctrlg-widget
    bindkey '^g' ctrlg-widget
    bindkey '^@' ctrlg-widget   # Ctrl + Space (한영 전환 생략 보조 단축키)

    # Zsh 에러 감지 훅
    ctrlg_error_hook() {
        local last_exit=\$?
        local last_cmd=\$(fc -ln -1 | xargs)
        if [ \$last_exit -ne 0 ] && [[ \"\$last_cmd\" != ctrlg* ]] && [[ \"\$last_cmd\" != cg* ]]; then
            ctrlg --analyze-error \"\$last_cmd\" \$last_exit
        fi
    }
    # precmd_functions 배열에 에러 훅 추가
    typeset -ag precmd_functions
    if [[ \${precmd_functions[(r)ctrlg_error_hook]} != ctrlg_error_hook ]]; then
        precmd_functions+=(ctrlg_error_hook)
    fi
fi"
    elif [ "$shell_name" = "bash" ]; then
        snippet="
# ctrlg AI CLI Integration
if command -v ctrlg &>/dev/null; then
    # Bash Ctrl+G 및 Ctrl+Space 위젯 바인딩
    _ctrlg_bash_bind() {
        local query=\"\$READLINE_LINE\"
        if [ -n \"\$query\" ]; then
            local result=\$(ctrlg --raw \"\$query\")
            READLINE_LINE=\"\$result\"
            READLINE_POINT=\$\{#READLINE_LINE\}
        fi
    }
    bind -x '\"\C-g\": _ctrlg_bash_bind'
    bind -x '\"\C-@\": _ctrlg_bash_bind' # Ctrl + Space (한영 전환 생략 보조 단축키)

    # Bash 에러 감지 훅
    ctrlg_error_hook() {
        local last_exit=\$?
        local last_cmd=\$(history 1 | sed 's/^[ ]*[0-9]*[ ]*//')
        if [ \$last_exit -ne 0 ] && [[ \"\$last_cmd\" != ctrlg* ]] && [[ \"\$last_cmd\" != cg* ]]; then
            ctrlg --analyze-error \"\$last_cmd\" \$last_exit
        fi
    }
    PROMPT_COMMAND=\"ctrlg_error_hook; \$PROMPT_COMMAND\"
fi"
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
