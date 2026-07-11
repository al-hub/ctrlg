# chmod

> 파일이나 디렉토리의 읽기, 쓰기, 실행 권한을 변경합니다.

- 특정 파일에 실행(+x) 권한 부여:
  chmod +x filename

- 모든 사용자에게 읽기 및 쓰기 권한 부여:
  chmod a+rw filename

- 소유자에게 8진수 기반 모든 권한(755) 부여:
  chmod 755 filename

- 재귀적으로 하위 모든 파일 및 디렉토리 권한 일괄 변경:
  chmod -R 755 /path/to/directory
