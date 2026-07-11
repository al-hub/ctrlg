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

echo "✅ 설치가 완료되었습니다!"
echo "이제 터미널에서 'ctrlg [자연어]' 또는 'cg [자연어]' 명령어를 바로 사용할 수 있습니다."
echo "(만약 작동하지 않는다면 PATH에 '$HOME/.local/bin'이 등록되어 있는지 확인하세요.)"
