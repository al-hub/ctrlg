# tar

> 아카이브 유틸리티. 종종 gzip 이나 bzip2 와 같은 압축 유틸리티와 결합됩니다.

- 아카이브 파일을 생성하고 특정 폴더를 압축:
  tar -cvf archive.tar /path/to/directory

- gzip 으로 아카이브 생성 및 압축 (tar.gz):
  tar -czvf archive.tar.gz /path/to/directory

- bzip2 로 아카이브 생성 및 압축 (tar.bz2):
  tar -cjvf archive.tar.bz2 /path/to/directory

- 특정 아카이브 파일(tar, tar.gz, tar.bz2 등)을 현재 디렉토리에 압축 해제:
  tar -xvf archive.tar.gz

- 아카이브 파일을 특정 대상 디렉토리에 압축 해제:
  tar -xvf archive.tar -C /path/to/directory
