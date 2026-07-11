# grep

> 정규식 패턴을 사용하여 파일 내의 일치하는 줄을 검색하고 출력합니다.

- 파일 내에서 특정 단어(패턴) 검색:
  grep "search_pattern" filename

- 특정 디렉토리 내 모든 파일에서 하위 재귀적으로 검색:
  grep -r "search_pattern" /path/to/directory

- 대소문자 구분 없이 검색 (ignore-case):
  grep -i "search_pattern" filename

- 검색된 패턴에 정확히 일치하는 단어 단위로만 검색 (word):
  grep -w "search_pattern" filename

- 패턴과 일치하는 라인의 개수(count)만 출력:
  grep -c "search_pattern" filename

- 줄 번호(line-number)를 결과 앞에 함께 출력:
  grep -n "search_pattern" filename

- 일치하지 않는(invert-match) 라인만 반대로 출력:
  grep -v "search_pattern" filename
