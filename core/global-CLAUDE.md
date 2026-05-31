# 전역 Claude 행동 규칙

> 모든 프로젝트에 공통으로 적용되는 규칙.
> 이 파일은 `~/.claude/CLAUDE.md`에 복사하여 사용한다.
> 프로젝트별 규칙은 각 프로젝트의 `CLAUDE.md`를 따른다.

---

## 기본 행동 규칙

1. **컨텍스트 전환 시 CLAUDE.md 필독 및 확인 응답 필수** — 새 세션 시작, 컨텍스트 초과로 인한 재시작 등 어떤 이유로든 컨텍스트가 새로 열릴 때마다 반드시 `Read` 도구로 프로젝트 CLAUDE.md를 직접 읽고, 사용자의 첫 요청에 응답하기 전에 **"CLAUDE.md 확인 완료. 이번 요청과 관련된 규칙: [번호 및 요약]"** 형식으로 먼저 응답할 것
2. **CLAUDE.md 규칙 변경 시 즉시 재독** — 세션 중 CLAUDE.md에 규칙이 추가·수정된 경우 변경된 내용을 즉시 다시 읽고 이후 작업에 반영

---

## 커밋 메시지 규칙

- 작업 내용을 간결하게 서술. `Co-Authored-By` 라인 추가하지 않는다.
- 한국어 또는 영어 중 프로젝트 관례를 따른다.

---

## 위험 동작 제한 규칙

### 절대 금지 — 어떤 상황에서도 실행하지 않는다
> `~/.claude/settings.json` deny list에도 등록되어 있어 하네스 수준에서 차단됨

- `rm -rf`, `rm -r` — 재귀 파일 삭제
- `git push --force`, `git push -f` — 원격 브랜치 강제 푸시
- `git reset --hard` — 미커밋 변경사항 전체 폐기
- `git clean -f`, `git clean -fd` — 추적되지 않는 파일 삭제
- `kill -9` — 프로세스 강제 종료
- `DROP TABLE`, `DROP DATABASE` — 테이블·DB 삭제
- `TRUNCATE TABLE` — 전체 레코드 삭제
- `.env`, 프로덕션 시크릿 파일 수정·커밋

### 반드시 확인 후 실행 — 실행 전 사용자에게 되물을 것

**Bash 도구** — PreToolUse 훅(`pre_tool_use_confirm.sh`)이 아래 패턴을 자동 차단함

- DB 레코드 `INSERT` / `UPDATE` / `DELETE`
- `ALTER TABLE` — 스키마 파괴적 변경
- `git rebase` — 히스토리 재작성

**Edit / Write 도구** — PreToolUse 훅(`pre_tool_use_file_guard.sh`)이 아래 민감 파일을 자동 차단함

- `application*.yml` — Spring Boot 설정 파일
- `.env`, `.env.*` — 환경변수 파일
- `.claude/settings.json` — 하네스 설정 파일
- `.claude/hooks/*.sh` — 훅 스크립트

---

## 승인 컨벤션

### `# user-confirmed` — Bash 확인 필요 명령어 재시도

훅이 Bash 명령어를 차단하면:

1. 실행하려는 명령어, 목적, 영향 범위를 사용자에게 설명
2. 명령어를 직접 보여주고 실행 여부를 묻는다
3. 사용자가 승인하면 명령어 끝에 `# user-confirmed` 주석을 추가하여 재시도

```bash
mysql -e "DELETE FROM tb_test WHERE id=1" # user-confirmed
git rebase main # user-confirmed
```

> ⚠️ `# user-confirmed`는 사용자가 직접 승인한 경우에만 추가한다.

### 파일 수정 승인 — Edit / Write 민감 파일 재시도

훅이 민감 파일 수정을 차단하면:

1. 수정하려는 파일, 변경 내용, 목적을 사용자에게 설명
2. 변경 diff를 보여주고 수정 여부를 묻는다
3. 승인 후 아래 명령어로 일회성 승인 토큰을 생성하고 즉시 Edit/Write 재시도

```bash
# 파일 경로는 절대 경로
echo "/절대/경로/application.yml" > "$HOME/.claude/.file_edit_approved" # user-confirmed
```

> ⚠️ 승인 토큰은 일회성이다. 토큰 생성 직후 바로 재시도해야 하며, 임의로 토큰을 생성해 훅을 우회하지 않는다.
