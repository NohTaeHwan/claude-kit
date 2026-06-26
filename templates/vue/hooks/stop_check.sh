#!/bin/bash
# Stop 훅: 위험도 높은 파일 변경 감지 및 코드 리뷰 권장
#
# 동작 방식:
#   1. Claude가 작업을 마치려 할 때 자동 실행
#   2. git 변경 파일 중 위험 패턴과 일치하는 파일이 있으면 stderr로 경고 출력
#   3. 차단(exit 2)이 아닌 권장(exit 0) — /code-review 실행을 유도
#   4. stop_hook_active = true 이면 재시작된 세션이므로 즉시 통과 (무한 루프 방지)

INPUT=$(cat)

# 무한 루프 방지 — 훅으로 재시작된 세션은 즉시 통과
HOOK_ACTIVE=$(echo "$INPUT" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(d.get('stop_hook_active', False))" \
    2>/dev/null || echo "False")
[ "$HOOK_ACTIVE" = "True" ] && exit 0

# ── 변경 파일 수집 (커밋되지 않은 변경 + 신규 파일) ──────────────────────────
CHANGED_FILES=$(
    { git diff --name-only HEAD 2>/dev/null
      git ls-files --others --exclude-standard 2>/dev/null; } | sort -u
)

[ -z "$CHANGED_FILES" ] && exit 0

# ── Vue 위험 파일 패턴 ────────────────────────────────────────────────────────
# - src/router/        : Navigation guard — 보호 경로 노출 위험
# - useAuth / usePermission : 인증·권한 composable
# - stores/auth / stores/user : Pinia 인증·사용자 상태
# - src/api / src/services   : API 인터셉터 (토큰 처리)
# - vite.config        : 빌드·proxy 설정
# - .github/workflows/ : CI/CD 파이프라인
RISKY_FILES=$(echo "$CHANGED_FILES" | grep -iE \
    "src/router/|useAuth|usePermission|stores/(auth|user)|src/(api|services)/|vite\.config\.|\.github/workflows/")

if [ -n "$RISKY_FILES" ]; then
    echo "" >&2
    echo "⚠️  [stop-check] 위험도 높은 파일이 변경되었습니다 — /code-review 실행을 권장합니다." >&2
    echo "" >&2
    echo "$RISKY_FILES" | sed 's/^/    /' >&2
    echo "" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "▶  /code-review 를 실행하고 리뷰 완료 후 완료 처리하세요." >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
fi

exit 0
