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
    └── spring-boot/
        └── CLAUDE.md              ← 프로젝트 CLAUDE.md 시작점
```

---

## 설치

### 1. 전역 설정 (최초 1회)

```bash
# 훅 디렉토리 생성
mkdir -p ~/.claude/hooks

# 훅 스크립트 복사
cp core/hooks/pre_tool_use_confirm.sh ~/.claude/hooks/
cp core/hooks/pre_tool_use_file_guard.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh

# CLAUDE.md 복사
cp core/global-CLAUDE.md ~/.claude/CLAUDE.md
```

`core/settings.json`의 `/YOUR_HOME/` 부분을 실제 홈 디렉토리로 교체한 뒤 복사한다.

```bash
# 예시 (macOS)
sed 's|/YOUR_HOME/|/Users/yourname/|g' core/settings.json > ~/.claude/settings.json
```

> ⚠️ `~/.claude/settings.json`에 기존 설정(`theme` 등)이 있으면 수동으로 병합한다.

### 2. 프로젝트 설정 (새 프로젝트마다)

원하는 템플릿을 복사한 뒤 프로젝트에 맞게 커스텀한다.

```bash
# Spring Boot 프로젝트 예시
cp templates/spring-boot/CLAUDE.md /path/to/your-project/CLAUDE.md
```

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

`templates/spring-boot/CLAUDE.md`를 복사한 뒤 아래 항목을 프로젝트에 맞게 채운다.

| 항목 | 설명 |
|---|---|
| ORM 방식 | JPA / MyBatis 등 사용 방식과 규칙 |
| 예외 클래스명 | 프로젝트에서 사용하는 비즈니스 예외 클래스명 |
| 에러코드 체계 | 도메인별 에러코드 prefix 및 목록 |
| Swagger 그룹 구성 | 도메인별 GroupedOpenApi 구성 |
| 참고 문서 이정표 | 프로젝트 docs/ 구조에 맞게 표 작성 |
| Git remote | SSH 원격 주소 |

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

### v1.0.0 — 26.06.01
- 최초 릴리즈
- `core/`: 전역 deny list(10개), Bash SQL/git 차단 훅, Edit/Write 민감 파일 보호 훅
- `templates/spring-boot/`: Spring Boot 프로젝트 CLAUDE.md 시작점
- `# user-confirmed` 및 파일 수정 승인 토큰 컨벤션 정립