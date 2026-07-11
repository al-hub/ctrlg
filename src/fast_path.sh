#!/usr/bin/env bash

# Fast Path 즉시 매핑 처리
# 일치하는 명령어가 있으면 해당 명령어를 표준출력하고 0을 리턴, 없으면 1을 리턴
check_fast_path() {
    local input="$1"
    case "$input" in
        *현재*위치*|*현재*폴더*|*현재*디렉토리*|*pwd*)      { echo "pwd"; return 0; } ;;
        *하위*목록*|*현재*목록*|*ls*|*파일*목록*)       { echo "ls -la"; return 0; } ;;
        *디스크*용량*|*df*|*저장*공간*)                 { echo "df -h"; return 0; } ;;
        *디스크*사용량*|*du*|*폴더*용량*)               { echo "du -sh . 2>/dev/null || du -sh"; return 0; } ;;
        *시각*|*date*|*시간*)                           { echo "date"; return 0; } ;;
        *사용자*|*whoami*)                             { echo "whoami"; return 0; } ;;
        *프로세스*|*ps*)                               { echo "ps aux | head -20"; return 0; } ;;
        *메모리*|*free*)                               { echo "free -h"; return 0; } ;;
        *hostname*|*호스트*)                           { echo "hostname"; return 0; } ;;
    esac
    return 1
}
