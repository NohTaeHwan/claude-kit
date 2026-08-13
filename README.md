# claude-kit

어떤 프로젝트에서도 바로 사용할 수 있는 Claude Code 하네스 모음.
전역 규칙(보호·차단)은 한 번 설정하고, 프로젝트 템플릿은 복사해서 시작한다.

---

## 구조

```
claude-kit/
├── core/                          ← 전역 적용 (~/.claude/ 에 복사)
│   ├── global-CLAUDE.md           ← ~/.claude/CLAUDE.md
│   ├── settings.json              ← ~/.claude/settings.json (훅 경로 수정 필요)
│   └── hooks/
│       ├── pre_tool_use_confirm.sh    ← Bash SQL/git 차단
│       └── pre_tool_use_file_guard.sh ← Edit/Write 민감 파일 보호
└── templates/
    ├── spring-boot/
    │   ├── CLAUDE.md              ← 프로젝트 CLAUDE.md 시작점
    │   ├── settings.json          ← 프로젝트 .claude/settings.json (Stop·PreToolUse 훅 설정)
    │   ├── hooks/
    │   │   ├── stop_build_check.sh            ← Stop 훅: 컴파일·테스트 검증 + 코드 검수 분석
    │   │   └── pre_tool_use_mark_code_change.sh ← PreToolUse 훅: 코드 변경 마커 생성
    │   └── review/
    │       ├── review_guide.py    ← 검수 분석 스크립트 (diff → finding → JSON 출력)
    │       └── review-rules.json  ← 검수 규칙 15개 (Critical·High·Medium)
    └── vue/
        ├── CLAUDE.md              ← Vue 3 프로젝트 CLAUDE.md 시작점
        ├── settings.json          ← 프로젝트 .claude/settings.json (Stop 훅 설정)
        └── hooks/
            └── stop_check.sh          ← Stop 훅: 위험 파일 변경 감지 및 코드 리뷰 권장
```

---

## 사용 방법

> 설치 전 [주의사항](#주의사항)을 먼저 확인하세요.

### 최초 설치

```bash
git clone git@github.com:NohTaeHwan/claude-kit.git ~/dev/claude-kit
cd ~/dev/claude-kit
chmod +x install.sh          # 실행 권한 부여 (최초 1회)
./install.sh
```

`install.sh`가 자동으로 처리하는 것:
- `~/.claude/hooks/` 에 심볼릭 링크 연결 (훅 스크립트)
- `~/.claude/CLAUDE.md` 에 심볼릭 링크 연결 (전역 행동 규칙)
- `~/.claude/settings.json` 생성 (HOME 경로 자동 치환, 기존 UI 설정 보존)

### 업데이트

```bash
git pull         # 훅·CLAUDE.md는 심볼릭 링크로 자동 반영
./install.sh     # settings.json이 변경된 경우에만 추가 실행
```

> `install.sh`는 `ln -sf`를 사용하므로 중복 실행해도 안전하다.

> ⚠️ **레포 디렉토리를 이동한 경우** 심볼릭 링크가 깨진다. 이동 후 반드시 `./install.sh`를 재실행해야 한다. (스크립트가 깨진 링크를 자동 감지하고 현재 경로로 갱신한다.)

### 새 프로젝트 시작

```bash
# Spring Boot 프로젝트
./install.sh --project /path/to/your-project spring-boot

# Vue 프로젝트
./install.sh --project /path/to/your-project vue

# 훅·설정만 업데이트 (CLAUDE.md 커스텀 내용 유지)
./install.sh --project /path/to/your-project vue --hooks-only
./install.sh --project /path/to/your-project spring-boot --hooks-only
```

설치되는 파일:

| 템플릿 | 파일 |
|---|---|
| spring-boot | `CLAUDE.md`, `.claude/settings.json`, `.claude/hooks/stop_build_check.sh`, `.claude/hooks/pre_tool_use_mark_code_change.sh`, `.claude/review/review_guide.py`, `.claude/review/review-rules.json` |
| vue | `CLAUDE.md`, `.claude/settings.json`, `.claude/hooks/stop_check.sh` |

설치 후 `CLAUDE.md`를 열어 프로젝트에 맞게 내용을 채운다.

> 기존 파일이 있으면 `.bak`으로 백업 후 덮어쓴다.

---

## 전역 vs 프로젝트 구분

| | 전역 (`~/.claude/`) | 프로젝트 (`.claude/`) |
|---|---|---|
| **settings.json** | deny list + 훅 config | allow list, 프로젝트 추가 훅 |
| **hooks/** | SQL/git 차단, 민감 파일 보호 | 빌드·테스트 검증 (프로젝트별) |
| **CLAUDE.md** | 위험 동작 제한, 승인 컨벤션 | 프로젝트 구조, 개발 규칙 |

---

## 승인 컨벤션 요약

**Bash 차단 시** — 사용자 승인 후 명령어 끝에 `# user-confirmed` 추가

```bash
git rebase main # user-confirmed
mysql -e "DELETE FROM tb WHERE id=1" # user-confirmed
```

**민감 파일 수정 시** — 사용자 승인 후 일회성 토큰 생성 후 즉시 재시도

```bash
echo "/절대/경로/application.yml" > "$HOME/.claude/.file_edit_approved" # user-confirmed
```

---

## 프로젝트 템플릿 커스텀 가이드

### Spring Boot

`templates/spring-boot/CLAUDE.md`를 복사한 뒤 아래 항목을 프로젝트에 맞게 채운다.

| 항목 | 설명 |
|---|---|
| ORM 방식 | JPA / MyBatis 등 사용 방식과 규칙 |
| 예외 클래스명 | 프로젝트에서 사용하는 비즈니스 예외 클래스명 |
| 에러코드 체계 | 도메인별 에러코드 prefix 및 목록 |
| Swagger 그룹 구성 | 도메인별 GroupedOpenApi 구성 |
| 참고 문서 이정표 | 프로젝트 docs/ 구조에 맞게 표 작성 |
| Git remote | SSH 원격 주소 |

### Vue

`templates/vue/CLAUDE.md`를 복사한 뒤 아래 항목을 프로젝트에 맞게 채운다.

| 항목 | 설명 |
|---|---|
| UI 라이브러리 | Vuetify / Element Plus / shadcn-vue / 없음 등 |
| API 통신 라이브러리 | axios / fetch 등 |
| 참고 문서 이정표 | 프로젝트 docs/ 구조에 맞게 표 작성 |
| Git remote | SSH 원격 주소 |

---

## 주의사항

> ⚠️ **`python3`가 설치되어 있어야 한다.**
> `install.sh` 전역 설치 시 `settings.json` 병합에 `python3`를 사용한다.
> 미설치 환경에서는 설치가 중간에 실패하고 `settings.json`이 생성되지 않는다.
> 설치 전 `python3 --version`으로 확인할 것.

> ⚠️ **재설치 시 `.bak` 파일이 덮어써진다.**
> `install.sh`는 기존 파일을 `.bak`으로 백업하지만, 재실행할 때마다 이전 `.bak`을 덮어쓴다.
> 최초 설치 전 원본을 별도로 보존해야 한다면 수동으로 백업할 것.

---

## 코드 검수 가이드 (Spring Boot)

빌드와 테스트가 통과해도 트랜잭션 경계, 권한 검사, 외부 부작용, 금액 계산처럼 **사람이 직접 확인해야 할 지점**은 남습니다. Claude가 이런 영역을 변경했을 때 "어디를 봐야 하는가"를 알려주는 기능입니다.

**동작 방식:** Claude가 Java 코드를 변경하면 Stop 훅이 컴파일·테스트 완료 후 자동으로 diff를 분석합니다. 위험 신호가 발견된 경우에만 같은 Claude가 **검수 포인트 3~7개**를 리포트로 출력합니다.

```
코드 검수 리포트

검수 포인트 1
- 위치: UserService.deleteAccount(), line 84
- 이유: @Transactional 경계 안에서 외부 API 호출
- 확인: 외부 호출 실패 시 롤백 범위와 보상 처리 확인

자동 검증
- 컴파일 PASS / UserServiceTest PASS
```

**규칙 분류 (`review-rules.json` — 15개):**

| 단계 | 대상 |
|---|---|
| Critical | 인증·인가, 데이터 삭제, 금액·정산, 시크릿 하드코딩, DB 마이그레이션 |
| High | 트랜잭션 경계, 락·동시성, 비동기·스케줄러, 외부 호출, 공개 API 계약, 빈 catch |
| Medium | TODO·임시 구현, 타임아웃 없는 외부 호출, 무제한 조회 |

Critical·High 규칙 탐지 → 리포트 생성. 대응 테스트 없음은 미검증 항목으로 기록하며, Medium만 있으면 통과.

리포트는 같은 Claude가 출력하며, 별도 에이전트·파일 누적 없음. 후속 수정 여부는 사용자 판단.

---

## 보호 대상 파일 (Edit/Write 자동 차단)

| 패턴 | 유형 |
|---|---|
| `application*.yml` | Spring Boot 설정 |
| `.env`, `.env.*` | 환경변수 |
| `.claude/settings.json` | 하네스 설정 |
| `.claude/hooks/*.sh` | 훅 스크립트 |

---

## 업데이트

### v1.7.1 — 26.08.13
- `templates/spring-boot/hooks/stop_build_check.sh` — 동일 파일을 여러 번 Edit/Write해도 변경 파일과 대응 테스트 클래스를 최초 등장 순서로 한 번만 처리
- `templates/spring-boot/review/review_guide.py` — `changedFiles`, `executedTests`, 동일 `ruleId + file + line + symbol` finding 중복 제거
- 중복 분석 입력·finding·Gradle·Maven 실행 경로와 공백 포함 파일 경로를 검증하는 회귀 테스트 6개 추가

### v1.7.0 — 26.08.05
- `templates/spring-boot/review/review_guide.py` 추가 — diff 분석 스크립트. contentPatterns 기반 finding 생성, reviewRequired 판정, JSON 출력
- `templates/spring-boot/review/review-rules.json` 추가 — 15개 MVP 검수 규칙 (Critical 5 / High 7 / Medium 3)
- `templates/spring-boot/hooks/stop_build_check.sh` 개편 — 컴파일·테스트 완료 후 review_guide.py 실행. reviewRequired=true 시 리포트 지시문 출력 후 exit 2. 기존 "위험 파일 경고" 섹션 제거 (규칙 파일로 대체)
- `install.sh` — review/ 디렉토리 복사 로직 추가
- `tests/test_review_guide.py` 추가 — 9개 단위 테스트

### v1.6.0 — 26.07.07
- `templates/spring-boot/hooks/pre_tool_use_mark_code_change.sh` 추가 — Claude가 Edit/Write로 `.java`/`.kt`/빌드 파일 수정 시 마커(`.claude/.code_changed`) 생성
- `templates/spring-boot/settings.json` — PreToolUse 훅 추가 (matcher: Edit, Write로 명시)
- `templates/spring-boot/hooks/stop_build_check.sh` 전면 개편
  - 기존: 매 응답마다 전체 `./gradlew test` 실행 → 토론 중에도 테스트 남발
  - 변경: 이번 턴에 Claude가 수정한 파일이 있을 때만 실행, 수정 파일에 대응하는 테스트 클래스만 타겟 실행
  - 탐색 결과 투명 출력 — 대응 테스트 없을 때 탐색 경로 표시 (`→ 탐색: ... (없음)`)
  - 테스트 통과 시 `✅` 성공 메시지 출력
- `install.sh` — settings.json 설치 시 훅 명령어를 절대경로로 자동 치환 (CWD 무관하게 스크립트 탐색)
- 스크립트 내부 PROJECT_ROOT 도출 방식 변경 — `git rev-parse` 대신 `SCRIPT_DIR` 기반으로 안정화
- `core/settings.json` — deny list에 `rm -f` 추가

### v1.5.4 — 26.06.26
- `core/hooks/pre_tool_use_confirm.sh` — `git stash` 확인 필요 패턴 추가

### v1.5.3 — 26.06.26
- `core/settings.json` — `permissions.allow` 추가: 파일 읽기·git 조회·파일 탐색 등 안전한 작업 자동 허용으로 불필요한 승인 요청 감소

### v1.5.2 — 26.06.26
- `core/global-CLAUDE.md` — 요구사항 명확화 기준 추가: 질문해야 할 때 vs 자율 진행할 때 기준 명시

### v1.5.1 — 26.06.26
- `install.sh` — `--hooks-only` 플래그 추가: CLAUDE.md 제외하고 훅·settings.json만 복사 (기존 프로젝트 업데이트 시 커스텀 내용 보존)

### v1.5.0 — 26.06.26
- `templates/spring-boot/hooks/stop_build_check.sh` — 위험도 높은 파일 변경 시 `/code-review` 권장 경고 추가
- `templates/vue/hooks/stop_check.sh` 추가 — Vue Stop 훅: 위험 파일 감지 및 코드 리뷰 권장
- `templates/vue/settings.json` 추가 — Vue Stop 훅 설정
- `install.sh` — 프로젝트 설치 로직 일반화 (settings.json + hooks/ 존재 시 자동 복사)

### v1.4.0 — 26.06.19
- `install.sh` — `--project` 플래그 추가로 프로젝트 설치 지원 (spring-boot / vue)
- `install.sh` — 기존 파일 `.bak` 백업 후 덮어쓰도록 개선

### v1.3.0 — 26.06.19
- `templates/spring-boot/hooks/stop_build_check.sh` 추가 — Stop 훅으로 컴파일·테스트 자동 검증, 실패 시 작업 완료 차단
- `templates/spring-boot/settings.json` 추가 — Stop 훅 설정 템플릿
- README 새 프로젝트 시작 가이드 업데이트

### v1.2.0 — 26.06.14
- `templates/vue/` 추가 — Vue 3 + Vite + TypeScript 프로젝트 CLAUDE.md 시작점
- Composable·Pinia store·Props/Emits 패턴 코드 예시 포함

### v1.1.0 — 26.06.01
- `install.sh` 추가 — 심볼릭 링크 설정 + settings.json HOME 경로 자동 치환 + 기존 UI 설정 보존 병합
- README 사용 방법 섹션 추가

### v1.0.0 — 26.06.01
- 최초 릴리즈
- `core/`: 전역 deny list(10개), Bash SQL/git 차단 훅, Edit/Write 민감 파일 보호 훅
- `templates/spring-boot/`: Spring Boot 프로젝트 CLAUDE.md 시작점
- `# user-confirmed` 및 파일 수정 승인 토큰 컨벤션 정립