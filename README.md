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
    │   ├── settings.json          ← 프로젝트 .claude/settings.json (Stop 훅 설정)
    │   └── hooks/
    │       └── stop_build_check.sh    ← Stop 훅: 컴파일·테스트 자동 검증
    └── vue/
        └── CLAUDE.md              ← Vue 3 프로젝트 CLAUDE.md 시작점
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
```

설치되는 파일:

| 템플릿 | 파일 |
|---|---|
| spring-boot | `CLAUDE.md`, `.claude/settings.json`, `.claude/hooks/stop_build_check.sh` |
| vue | `CLAUDE.md` |

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

## 보호 대상 파일 (Edit/Write 자동 차단)

| 패턴 | 유형 |
|---|---|
| `application*.yml` | Spring Boot 설정 |
| `.env`, `.env.*` | 환경변수 |
| `.claude/settings.json` | 하네스 설정 |
| `.claude/hooks/*.sh` | 훅 스크립트 |

---

## 업데이트

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