# 🖥️ 로컬 LLM 기반 크로스플랫폼 터미널 AI 도우미 (ctrlg) 구축 계획서 - v0.4.0

이 가이드는 로컬 소형 언어 모델(Ollama SLM)의 한계와 기존 AI CLI들의 UX(사용자 경험)적 불편함을 극복하기 위해, **"터미널 흐름을 방해하지 않는 비서"**를 지향하는 차세대 터미널 AI 도우미 `ctrlg` (축약어: `cg`)의 핵심 목적과 구체적인 구현 방법을 정의합니다.

> [!IMPORTANT]
> **핵심 제약 사항 (Prerequisites)**
> 본 도구는 오프라인 로컬 환경에서 작동하므로, 실행 전에 반드시 **Ollama가 로컬에 설치**되어 있어야 하며, 사용할 **소형 모델(추천: `gemma2:2b`)이 사전에 다운로드되어 메모리에 활성화**되어 있어야 정상 작동합니다.

---

## 1. 프로젝트 핵심 목적 (Core Mission)
 
 기존 AI CLI 도구들은 "자연어 입력 ➡️ AI 응답 대기 ➡️ eval 강제 혹은 y/N 확인"의 모놀리식 방식을 취해 **타이핑 흐름을 단절**시키고, 오작동에 대한 **불안감**을 가중시켰습니다. 본 프로젝트는 다음 3대 철학을 구현하여 터미널에 AI를 가장 자연스럽게 녹여내는 것을 목적으로 합니다.
 
 ```mermaid
 graph TD
     A[사용자 자연어 타이핑] --> B{Ctrl + G 입력}
     B --> C[FZF 대화형 모드 진입]
     C --> D{질의 선택 / 새 입력}
     D -->|히스토리 선택| E[선택된 명령어 즉시 프롬프트 주입]
     D -->|신규 질의| F[로컬 RAG 컨텍스트 매칭 & AI 실시간 추론]
     F --> G[진행 로그 실시간 노출 및 명령어 생성]
     G --> H[최종 명령어를 쉘 입력창에 자동 주입]
 ```
 
 ---
 
 ## 2. 3대 대안 설계 및 구체적 구현 방법 (How-To)
 
 ### 🎯 철학 ① : 대화형 FZF 모드와 쉘 버퍼 주입 (UX 개선)
 * **목적**: 기존 쉘 환경과의 간섭 및 화면 깨짐을 원천 방지하기 위해, `Ctrl + G` 입력 시 독립된 FZF 대화창을 열어 히스토리 선택 및 자연어 질의를 수행하고, 추천된 명령어만 쉘 프롬프트 버퍼에 주입합니다.
 
 #### 🛠️ 구체적 구현 방법 (Zsh / Bash Widget 연동)
 사용자가 터미널에 설명(예: `하위폴더 *.zip 파일 목록`)을 적고 **`Ctrl + G`**를 누르면, 대화형 TUI 창이 열립니다.
 
 * **Zsh (`~/.zshrc`) 구현 방법**:
   ```zsh
   # Zsh Line Editor (ZLE)용 위젯 함수
   ctrlg-widget() {
       local query="$BUFFER"
       # Zsh 에디터 일시 중지
       zle -I
       # 대화형 FZF 화면 실행 (UI는 stderr로, 최종 결과는 stdout으로 획득)
       local result=$(ctrlg --interactive "$query")
       if [ -n "$result" ]; then
           BUFFER="$result"
       else
           BUFFER="$query"
       fi
       CURSOR=$#BUFFER
       zle redisplay
   }
   
   # 위젯 등록 및 단축키 Ctrl+G 매핑
   zle -N ctrlg-widget
   bindkey '^g' ctrlg-widget
   ```
 
 * **Bash (`~/.bashrc`) 구현 방법**:
   ```bash
   # readline을 이용해 대화형 실행 결과를 입력 버퍼에 대입
   _ctrlg_bash_bind() {
       local query="$READLINE_LINE"
       history -s "$query"
       local result=$(ctrlg --interactive "$query")
       if [ -n "$result" ]; then
           READLINE_LINE="$result"
       else
           READLINE_LINE="$query"
       fi
       READLINE_POINT=${#READLINE_LINE}
   }
   # Ctrl+G (\C-g) 단축키 바인딩
   bind -x '"\C-g": _ctrlg_bash_bind'
   ```
 
 ---
 
 ### 🎯 철학 ② : 에러 발생 시 자동 가이드 (Reactive 도우미)
 * **목적**: 사용자가 입력한 명령어가 실패(`exit code != 0`)했을 때 백그라운드에서 깨어나 해결책을 제시해 주는 에러 해결 비서입니다.
 
 > [!NOTE]
 > **에러 감지 훅 비활성화 안내 (v0.3.1)**
 > 평상시 터미널 쉘 프롬프트의 극대화된 반응성 및 고속 전환 성능을 유지하기 위해, 매 명령어 실행 직후 감지하는 에러 해결 추천 훅(`ctrlg_error_hook`)은 현재 버전에서 비활성화 처리되어 있습니다.
 
 #### 🛠️ 구체적 구현 방법 (쉘 훅 연동 예시)
 쉘 훅(`precmd` 또는 `PROMPT_COMMAND`)을 활용해 직전 명령어 실패 여부를 감지합니다.
 
 * **Bash / Zsh 공통 연동 훅 예시**:
   ```bash
   ctrlg_error_hook() {
       local last_exit=$?
       local last_cmd=$(history 1 | sed 's/^[ ]*[0-9]*[ ]*//')
       if [ $last_exit -ne 0 ] && [[ "$last_cmd" != ctrlg* ]] && [[ "$last_cmd" != cg* ]]; then
           ctrlg --analyze-error "$last_cmd" $last_exit
       fi
   }
   ```-N ctrlg-widget
  bindkey '^g' ctrlg-widget
  ```

* **Bash (`~/.bashrc`) 구현 방법**:
  Bash는 `Readline` 바인딩을 이용해 함수 실행 결과를 쉘 입력창에 넣을 수 있습니다.
  ```bash
  # readline을 이용해 입력 버퍼를 교체하는 쉘 매핑
  _ctrlg_bash_bind() {
      local query="$READLINE_LINE"
      if [ -n "$query" ]; then
          local result=$(ctrlg --raw "$query")
          READLINE_LINE="$result"
          READLINE_POINT=${#READLINE_LINE} # 커서 위치 설정
      fi
  }
  # Ctrl+G (\C-g) 단축키 바인딩
  bind -x '"\C-g": _ctrlg_bash_bind'
  ```

---

### 🎯 철학 ② : 에러 발생 시 자동 가이드 (Reactive 도우미)
* **목적**: 평소에는 가만히 있다가, 사용자가 입력한 명령어가 실패(`exit code != 0`)했을 때만 백그라운드에서 조용히 깨어나 해결책을 제시해 주는 자동 에러 해결 비서입니다.

#### 🛠️ 구체적 구현 방법 (쉘 훅 연동)
터미널 프롬프트가 다시 출력되기 직전에 동작하는 쉘 훅(`precmd` 또는 `PROMPT_COMMAND`)을 활용해 직전 명령어 실패 여부를 감지합니다.

* **Bash / Zsh 공통 연동 훅 (`~/.bashrc` 또는 `~/.zshrc`)**:
  ```bash
  # 직전 실행 명령어와 상태 값을 감지하는 함수
  ctrlg_error_hook() {
      local last_exit=$?
      # 직전에 실행한 실제 명령어 텍스트 추출
      local last_cmd=$(history 1 | sed 's/^[ ]*[0-9]*[ ]*//')

      # 종료 코드가 에러(0이 아님)이고, ctrlg 자체 명령어가 아닐 때 작동
      if [ $last_exit -ne 0 ] && [[ "$last_cmd" != ctrlg* ]] && [[ "$last_cmd" != cg* ]]; then
          # 백그라운드로 AI 에러 분석기 가동
          ctrlg --analyze-error "$last_cmd" $last_exit
      fi
  }

  # Bash 프로필 적용
  PROMPT_COMMAND="ctrlg_error_hook; $PROMPT_COMMAND"
  ```

---

### 🎯 철학 ③ : RAG (로컬 지식 베이스) 기반 초고속 매핑
* **목적**: 소형 모델이 갖는 지식 한계를 극복하기 위해, 오프라인 명령어 정보 사전을 지식 데이터베이스로 탑재하여 오답률을 낮추고 연산 속도를 비약적으로 단축시킵니다.

#### 🛠️ 구체적 구현 방법 (tldr 페이지 매핑)
로컬에 저장된 `tldr` 마크다운 문서 꾸러미를 RAG의 지식 창고로 활용합니다.

* **RAG 쉘 모듈 예시 (`src/rag_matcher.sh`)**:
  ```bash
  # 사용자의 입력을 분석하여 가장 근접한 명령어의 로컬 tldr 가이드를 찾아 반환
  get_tldr_context() {
      local input="$1"
      local tldr_path="$HOME/.local/share/tldr/pages/common"
      
      # 예: 입력에 '압축'이나 'tar'가 있다면 tar 가이드를 읽어와 프롬프트에 얹어줌
      for word in $input; do
          if [ -f "${tldr_path}/${word}.md" ]; then
              cat "${tldr_path}/${word}.md" | head -n 15
              return 0
          fi
      done
      return 1
  }
  ```

---

## 3. Windows PowerShell 및 WSL로의 확장 방법

이 3대 설계 철학은 윈도우 파워쉘 및 WSL 환경에서도 동일하게 이식 가능합니다.

* **PowerShell 쉘 버퍼 주입**:
  파워쉘의 PSReadLine 모듈을 활용하여 단축키 바인딩과 입력창 버퍼(`[Microsoft.PowerShell.PSConsoleReadLine]::Insert()`) 조작을 적용합니다.
* **WSL 로컬 RAG 공유**:
  윈도우와 WSL이 `tldr` 문서 폴더를 네트워크 공유 폴더(`/mnt/c/...`)로 싱크하여 사용하므로, 양쪽 세션에서 중복 다운로드 없이 단일 지식 베이스로 사용 가능합니다.
