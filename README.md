# claude-kit

프로젝트 초기 개발시 가져와서 바로 사용할 수 있도록 만든 Claude Code 개발 하네스입니다. \
Spring boot 로 개발하고 Claude code 사용자에게 최적화 되어있습니다. \
이 하네스를 통해 초기 프로젝트 AI Workflow 구축시 도움이 되길 바라는 마음에 만들게 되었습니다.
후에 나오는 설치방법을 통해 간편하게 설치하시고 사용하시면 됩니다.


## 주요 기능

| 기능             | 하는 일                                                                                              |
|------------------|------------------------------------------------------------------------------------------------------|
| 위험 동작 차단   | 위험한 명령(bash·git·Query..)을 실행 전에 멈추고 사용자 승인을 요청합니다.                           |
| 민감 파일 보호   | `application*.yml`, `.env`, Claude 설정·Hook 등의 수정을 차단 후 사용자 승인을 요청합니다.           |
| Hook 자동 테스트 | 코드 변경 후 Hook이 컴파일·관련 테스트를 실행합니다.                                                 |
| 코드 검수 가이드 | 개발한 주제(인증·트랜잭션·외부 호출 등)의 위험 등급 별로 사람의 검수가 권장되는 부분을 추천해줍니다. |
| API 개발 Skill   | API 추가·수정·삭제에 대한 skill 문서의 뼈대를 제공합니다 (현재는 spring 한정)                        |
| 프로젝트 템플릿  | 프로젝트 별 `CLAUDE.md`, settings, Hook을 제공합니다 (현재는 Spring Boot,Vue 제공)                   |

> API 개발 Skill은 `.claude/skills/` 한 곳에 설치하게됩니다. Claude Code와 OpenCode가 같은 Skill 원본을 읽기 때문에 skill 의 경우 OpenCode 사용이 가능합니다.

바로가기: [설치](#설치) · [전역 vs 프로젝트](#적용-범위-전역-vs-프로젝트) · [승인과 재실행](#승인과-재실행) · [Spring API Skill](#spring-api-개발-skill) · [코드 검수](#코드-검수-가이드-spring-boot) · [주의사항](#주의사항)

---

## 저장소 구조

<details>
<summary>디렉터리 구조 보기</summary>

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
    │   ├── review/
    │   │   ├── review_guide.py    ← 검수 분석 스크립트 (diff → finding → JSON 출력)
    │   │   └── review-rules.json  ← 검수 규칙 15개 (Critical·High·Medium)
    │   └── skills/
    │       ├── spring-api-create/ ← 신규 Spring MVC REST API 추가 Skill
    │       ├── spring-api-update/ ← 기존 API 변경 Skill
    │       ├── spring-api-delete/ ← API 제거·폐기 Skill
    │       └── spring-api-shared/ ← 프로젝트 탐지·TDD·문서·검증 공통 절차
    └── vue/
        ├── CLAUDE.md              ← Vue 3 프로젝트 CLAUDE.md 시작점
        ├── settings.json          ← 프로젝트 .claude/settings.json (Stop 훅 설정)
        └── hooks/
            └── stop_check.sh          ← Stop 훅: 위험 파일 변경 감지 및 코드 리뷰 권장
```

</details>

---

## 설치

> 처음 사용한다면 전역(global) 영역을 먼저 설치하고, 실제 개발 저장소에는 프로젝트 템플릿을 별도로 적용합니다. 설치 전에는 [주의사항](#주의사항)을 확인하도록 합니다.

### 1. 전역 설치

전역 설치는 모든 Claude Code 세션에 공통으로 적용할 위험 명령 차단과 민감 파일 보호를 설정합니다.

```bash
git clone git@github.com:NohTaeHwan/claude-kit.git ~/dev/claude-kit
cd ~/dev/claude-kit
chmod +x install.sh
./install.sh
```

설치 결과:

- `~/.claude/hooks/`에 전역 Hook 심볼릭 링크 연결
- `~/.claude/CLAUDE.md`에 전역 행동 규칙 심볼릭 링크 연결
- `~/.claude/settings.json` 생성 및 기존 UI 설정 보존

#### 전역 설정 업데이트

```bash
cd ~/dev/claude-kit
git pull
./install.sh
```

Hook과 `CLAUDE.md`는 심볼릭 링크로 연결되므로 저장소를 업데이트(pull)하면 바로 반영됩니다. `settings.json`이 바뀌었거나 저장소 경로를 옮겼다면 `./install.sh`를 다시 실행하면 됩니다.

### 2. 프로젝트 설치

프로젝트 설치는 저장소별 개발 규칙(claude.md), 자동 검증 Hook, 코드 검수 규칙과 Spring API Skill을 적용합니다.

```bash
# Spring Boot 전체 설치
./install.sh --project /path/to/your-project spring-boot

# Vue 전체 설치
./install.sh --project /path/to/your-project vue
```

#### 설치 모드

| 모드 | 설치 범위 | 사용 시점 |
|---|---|---|
| 기본 설치 | `CLAUDE.md`, settings, Hook과 템플릿이 제공하는 review·Skill | 새 프로젝트에 템플릿 전체를 적용할 때 |
| `--hooks-only` | settings, Hook, review | 기존 `CLAUDE.md`와 Skill을 유지하면서 검증 기능만 업데이트할 때 |
| `--skills-only` | Spring API Skill | 기존 Context·settings·Hook을 그대로 두고 Skill만 추가하거나 업데이트할 때 |

```bash
# Hook과 settings만 업데이트
./install.sh --project /path/to/your-project spring-boot --hooks-only
./install.sh --project /path/to/your-project vue --hooks-only

# Spring API Skill만 설치
./install.sh --project /path/to/your-project spring-boot --skills-only
```

템플릿별 기본 설치 결과:

| 템플릿 | 설치 파일 |
|---|---|
| spring-boot | `CLAUDE.md`, `.claude/settings.json`, `.claude/hooks/`, `.claude/review/`, `.claude/skills/spring-api-*` |
| vue | `CLAUDE.md`, `.claude/settings.json`, `.claude/hooks/stop_check.sh` |

기존 파일은 같은 위치에 `.bak`으로 백업한 뒤 교체하면 됩니다. 기본 설치 후에는 `CLAUDE.md`의 placeholder와 프로젝트별 규칙을 실제 저장소에 맞게 수정하시면 맞게 사용하실 수 있습니다.

---

## 적용 범위: 전역 vs 프로젝트

전역(global) 과 프로젝트 단위를 구분하여 각각의 영역에 적합한 규칙을 담았습니다. \
**전역 설정**은 모든 저장소에서 지켜야 할 공통 규칙입니다. **프로젝트** 설정은 해당 저장소의 구조와 검증 방법을 설명합니다.  
같은 역할을 두 위치에 중복해서 작성하지 않아야 하는점을 꼭 유의하셔야 합니다.

| 구분 | 전역 (`~/.claude/`) | 프로젝트 (`<project>/.claude/`, `CLAUDE.md`) |
|---|---|---|
| 적용 범위 | 모든 Claude Code 세션 | 해당 프로젝트 |
| `CLAUDE.md` | 위험 동작 제한, 승인 방식 | 기술 스택, 구조, 개발 규칙, 문서 이정표 |
| settings | 전역 deny list와 보호 Hook | 프로젝트별 허용 범위와 추가 Hook |
| Hook | SQL·Git 위험 명령 차단, 민감 파일 보호 | 코드 변경 감지, 컴파일·테스트, 코드 검수 |
| Skill | 설치하지 않음 | Spring API 추가·수정·삭제 Workflow |
| 설치 명령 | `./install.sh` | `./install.sh --project ...` |

---

## 승인과 재실행

명령어의 위험도에 따라 `완전 차단`, `차단 후 승인(Bash, 민감 파일)` , `자동 허용` 단계로 나뉩니다. \
AI 작업 context 중 시스템에 위험할 수 있는 작업을 방지하는 목적입니다.

| 구분 | 예시                                                                                     | 처리 방법                                  |
|---|------------------------------------------------------------------------------------------|--------------------------------------------|
| **완전 차단** | `rm -rf`, `git push --force`, `DROP TABLE`, `TRUNCATE TABLE`, ...                        | 재실행 불가                                |
| **차단 → 승인 후 재시도** | `DELETE FROM`, `ALTER TABLE`, `git rebase`, `application*.yml 수정`, `.env 수정`, ...    | 목적·영향을 설명하고 승인을 받은 뒤 재시도 |
| **자동 허용** | `git status`, `git log`, `ls`, `./gradlew test`, 일반 소스 파일 수정                     | 승인 없이 즉시 실행                        |

> Bash 명령은 `# user-confirmed` 주석을 붙여 재시도하고, Edit/Write는 일회성 경로 토큰을 생성한 뒤 재시도한다. 승인 범위는 해당 명령·파일 한 건에만 적용된다.

### 위험 Bash 명령 승인 절차

1. Hook이 위험한 Bash 명령을 차단
2. Claude가 명령과 영향 범위를 설명
3. 사용자가 해당 명령을 승인
4. 승인된 명령에만 `# user-confirmed`를 붙여 재실행

```bash
git rebase main # user-confirmed
mysql -e "DELETE FROM tb WHERE id=1" # user-confirmed
```

### 민감 파일 수정 승인 절차

1. Hook이 보호 대상 파일의 Edit/Write를 차단
2. Claude가 수정할 경로와 변경 목적을 설명
3. 사용자가 그 파일 수정을 승인
4. 해당 경로로 일회성 토큰을 만든 뒤 수정 재시도



```bash
echo "/절대/경로/application.yml" > "$HOME/.claude/.file_edit_approved" # user-confirmed
```

#### 보호 대상 파일 (Edit/Write 차단)

| 패턴 | 유형 |
|---|---|
| `application*.yml` | Spring Boot 설정 |
| `.env`, `.env.*` | 환경변수 |
| `.claude/settings.json` | 하네스 설정 |
| `.claude/hooks/*.sh` | 훅 스크립트 |

토큰은 경로가 정확히 일치하는 다음 수정 한 번에만 사용됩니다. \
다른 파일에는 적용되지 않으며, 수정 전에 미리 만들어 두지 않기 때문에 다른 파일 수정에는 재사용되지 않습니다.

---

## API 개발 Skill

API 추가·수정·삭제 요청을 서로 다른 Skill들을 통해 개발합니다. \ 
Claude가 현재 작업에 필요한 skill 절차를 읽어서 보다 정확한 개발을 하도록 합니다.

| Skill             | 사용 시점                                         | 주요 작업                                                                                          |
|-------------------|---------------------------------------------------|----------------------------------------------------------------------------------------------------|
| `spring-api-create` | 새로운 endpoint나 API 동작을 추가할 때            | 기존 코드 구조 확인 → 테스트 작성 → API 구현 → 테스트 결과와 API 명세·문서 확인                    |
| `spring-api-update` | 기존 API의 경로·메서드·요청·응답·동작을 변경할 때 | 기존 동작과 사용처 확인 → 테스트 작성 or 수정 → 코드 수정 → 테스트 결과와 API 명세·문서 확인       |
| `spring-api-delete` | 기존 endpoint를 제거하거나 폐기할 때              | 사용처와 영향 범위 확인 → 삭제 전 관련 테스트 확인 → 전용 코드·설정 제거 → 관련 API 명세·문서 정리 |

세 Skill은 다음 공통 절차를 가집니다.

```text
프로젝트·모듈 탐지
→ Gradle/Maven과 Java/Spring 버전 확인
→ Controller부터 데이터 접근 계층까지 기존 흐름 체크
→ JPA/MyBatis/영속성 불필요 분기 처리
→ 테스트 작성/코드 수정/테스트 결과 확인
→ 프로젝트에서 관리 중인 API 명세와 관련 문서에 변경 내용 반영
→ Agent 검증 후 Stop Hook 독립 검증
```

`.claude/skills/`는 Claude Code와 OpenCode가 함께 읽는 경로입니다. \ 
Skill만 추가하거나 업데이트할 때는 다음 명령을 사용하면 됩니다.

```bash
./install.sh --project /path/to/your-project spring-boot --skills-only
```

### NVIDIA SkillSpector 보안 검사

`spring-api-create`, `spring-api-update`, `spring-api-delete` Skill은 NVIDIA SkillSpector v2.9.5 검사에서 모두 `0/100`(LOW, SAFE)을 기록했으며, 보안 이슈가 발견되지 않았습니다.

---

## 프로젝트 템플릿 커스텀 가이드

전역 영역과 달리 프로젝트 별로 규칙, hook, skill 등을 따로 가지고 있습니다. \
전역은 설치하지만 프로젝트 단위에서는 이 구조를 그대로 복사하여 자신의 프로젝트에 붙여넣어 주는 방식으로 사용합니다. \
Claude.md 안에는 뼈대만 있으니 프로젝트의 입맛에 맞게 수정해주시면 됩니다.

### Spring Boot

`templates/spring-boot/CLAUDE.md`를 복사한 뒤 아래 항목을 프로젝트에 맞게 채우면 됩니다.

| 항목 | 설명 |
|---|---|
| ORM 방식 | JPA / MyBatis 등 사용 방식과 규칙 |
| 예외 클래스명 | 프로젝트에서 사용하는 비즈니스 예외 클래스명 |
| 에러코드 체계 | 도메인별 에러코드 prefix 및 목록 |
| Swagger 그룹 구성 | 도메인별 GroupedOpenApi 구성 |
| 참고 문서 이정표 | 프로젝트 docs/ 구조에 맞게 표 작성 |
| Git remote | SSH 원격 주소 |

### Vue

`templates/vue/CLAUDE.md`를 복사한 뒤 아래 항목을 프로젝트에 맞게 채운면 됩니다.

| 항목 | 설명 |
|---|---|
| UI 라이브러리 | Vuetify / Element Plus / shadcn-vue / 없음 등 |
| API 통신 라이브러리 | axios / fetch 등 |
| 참고 문서 이정표 | 프로젝트 docs/ 구조에 맞게 표 작성 |
| Git remote | SSH 원격 주소 |

---

## 코드 검수 가이드

코드의 빌드와 테스트가 완료했다고 하더라고 변경된 기능(트랜잭션 경계, 권한 검사, 외부 부작용, 금액 계산)에 따라서는 사람이 직접 검수가 권장 됩니다. 
AI agent 가 문법이나 컴파일 에러는 잡아낼 수 있을지 몰라도 도메인 적인 실수까지 잡아내기는 어렵다고 생각하여 해당 기능을 넣었습니다. 
코드 검수 가이드는 Claude가 검수가 필요힌 영역을 변경했을 때 검토할 파일과 이유를 컨텍스트 종료 지점에서 응답으로 안내해줍니다.

### 동작 순서

1. Claude가 Java 코드를 변경하면 PreToolUse Hook이 변경 사실을 기록
2. Hook이 컴파일과 관련 테스트를 실행
3. 검증이 끝나면 실제 diff를 15개의 코드 검수 규칙으로 분석 (review-rules.json)
4. Critical·High 신호가 있으면 `Stop hook feedback`으로 검수 내용 전달
5. 같은 Claude가 검수 포인트 3~7개를 출력 (Hook 탐지 결과와 Agent 추가 의견은 분리해서 표시)

### 리포트 예시

```
코드 검수 리포트

[Hook 자동 탐지 결과]

검수 포인트 1 (source: hook-rule)
- 위치: UserService.deleteAccount(), line 84
- 이유: @Transactional 경계 안에서 외부 API 호출
- 확인: 외부 호출 실패 시 롤백 범위와 보상 처리 확인

[Agent 추가 검토 의견]
- 추가 의견 없음

자동 검증
- 컴파일 PASS / UserServiceTest PASS
```

### 탐지 규칙

`review-rules.json`은 15개의 검수 관련 규칙을 위험도 별로 관리합니다.

| 단계 | 대상 |
|---|---|
| Critical | 인증·인가, 데이터 삭제, 금액·정산, 시크릿 하드코딩, DB 마이그레이션 |
| High | 트랜잭션 경계, 락·동시성, 비동기·스케줄러, 외부 호출, 공개 API 계약, 빈 catch |
| Medium | TODO·임시 구현, 타임아웃 없는 외부 호출, 무제한 조회 |

Critical·High 규칙 탐지 → 리포트 생성. 대응 테스트 없음은 미검증 항목으로 기록하며, Medium만 있으면 통과.

리포트는 같은 Claude가 출력하며, 별도 에이전트·파일 누적 없음. 후속 수정 여부는 사용자 판단.

---


## 주의사항

| 확인할 항목 | 내용                                                                                                                   |
|---|------------------------------------------------------------------------------------------------------------------------|
| `python3` | 전역 settings 병합과 프로젝트 Hook 경로 생성을 위해 필요합니다. 설치 전에 `python3 --version`으로 확인                 |
| 저장소 이동 | 전역 Hook과 `CLAUDE.md` 심볼릭 링크가 깨질 수 있습니다. 이동 후 새 경로에서 `./install.sh`를 다시 실행해주셔야 합니다. |
| `.bak` 보존 | 재설치할 때 이전 `.bak`도 새 백업으로 교체됩니다. 장기 보존이 필요한 원본은 설치 전에 별도로 복사해주세요.             |
| 설치 대상 symlink | 프로젝트의 `.claude`, Skill 디렉터리 또는 대상 파일이 symlink면 외부 경로 덮어쓰기를 방지하기 위해 설치를 중단합니다.  |
| `--skills-only` | 현재 Spring Boot 템플릿만 지원합니다. Vue에서 사용하면 오류로 종료돼요.                                                |

---

## 업데이트

### v1.8.1 — 26.09.03
- review-rules의 실제 로직 규칙이 일반 주석·Javadoc을 매칭하지 않도록 공통 필터 추가
- TODO·나중에·추후 탐지를 `//` 주석으로 한정하고, `codePoint` 오탐 및 컬렉션 `get()` 오탐 제거
- diff 매칭 줄의 enclosing method symbol 귀속 오류 수정 및 회귀 테스트 추가

### v1.9.0 — 26.09.04
- Spring Boot 템플릿에 `pre_tool_use_require_api_skill.sh` 추가 — `Controller.java` 수정 전에 현재 세션 transcript에서 `spring-api-create/update/delete` Skill 호출 흔적을 확인하고, 없으면 Edit/Write 차단
- Skill을 적용할 수 없는 API 작업 예외 상황을 위한 프로젝트별 일회성 승인 토큰 지원 및 API 범위 밖 Controller 작업의 명시적 비대상 선언 지원
- Spring Boot `CLAUDE.md`에 구현 전 `Skill 매칭: [Skill명]` 출력 체크포인트 추가
- API Skill 라우팅 Hook 회귀 테스트 추가

### v1.8.0 — 26.08.14
- `spring-api-create`, `spring-api-update`, `spring-api-delete` Skill과 공통 참조 문서 추가
- Spring API 추가·수정·삭제 시 프로젝트 구조 확인, 테스트 작성, 구현·리팩터링, API 명세·관련 문서 업데이트를 순서대로 진행
- `install.sh --skills-only` 추가 — 기존 `CLAUDE.md`, 훅, settings를 유지하면서 Skill만 설치
- Spring Boot `CLAUDE.md`에 Skill 라우팅과 실제 프로젝트 설정·기존 구조 우선 원칙 추가
- Skill 구조, 설치 모드, 백업, 반복 설치, 공백·특수문자 경로와 symlink 차단 회귀 테스트 추가
- README를 주요 기능, 전역/프로젝트 범위, 설치 모드, 승인·재실행 흐름 중심으로 개편

### v1.7.3 — 26.08.13
- 코드 검수가 필요할 때 `Stop hook error` 대신 `Stop hook feedback`으로 안내
- 검수 리포트 작성 흐름은 유지하면서 정상 동작이 오류처럼 보이던 문제 개선

### v1.7.2 — 26.08.13
- Stop Hook의 리포트 내용을 `Hook 자동 탐지 결과`와 `Agent 추가 검토 의견`으로 분리
- Agent 의견은 Hook 탐지가 아님을 명시하고, 의견이 없을 때는 `추가 의견 없음`으로 출력

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