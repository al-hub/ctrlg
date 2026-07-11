# find

> 디렉토리 트리 내에서 파일이나 디렉토리를 검색합니다.

- 특정 이름(와일드카드 지원)을 가진 파일 검색:
  find /path/to/directory -name "*.ext"

- 특정 텍스트를 대소문자 구분 없이 파일명에서 검색:
  find /path/to/directory -iname "*pattern*"

- 특정 파일 크기 조건(예: 10MB 초과)을 가진 파일 검색:
  find /path/to/directory -size +10M

- 최근 7일 동안 수정된 파일 검색:
  find /path/to/directory -mtime -7

- 최근 24시간(1일) 동안 수정되지 않은 파일 검색:
  find /path/to/directory -mtime +1

- 오직 디렉토리(d) 타입만 검색:
  find /path/to/directory -type d

- 오직 일반 파일(f) 타입만 검색:
  find /path/to/directory -type f
