#!/bin/bash
# Stop 훅: 작업 완료 전 컴파일·테스트 자동 검증
#
# 동작 방식:
#   1. Claude가 작업을 마치려 할 때 자동 실행
#   2. 컴파일 실패 또는 테스트 실패 시 exit 2로 차단 + 오류 내용을 stderr로 전달
#   3. Claude가 오류를 읽고 수정 후 재시도
#   4. stop_hook_active = true 이면 재시작된 세션이므로 즉시 통과 (무한 루프 방지)

INPUT=$(cat)

# 무한 루프 방지 — 훅으로 재시작된 세션은 즉시 통과
HOOK_ACTIVE=$(echo "$INPUT" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(d.get('stop_hook_active', False))" \
    2>/dev/null || echo "False")
[ "$HOOK_ACTIVE" = "True" ] && exit 0

# ── 코드 변경 여부 확인 — 변경 없으면 컴파일·테스트 건너뜀 ──────────────────
CODE_CHANGED=$(
    { git diff --name-only HEAD 2>/dev/null
      git ls-files --others --exclude-standard 2>/dev/null; } | \
    grep -E "^src/.*\.(java|kt|groovy)$|^build\.gradle$|^pom\.xml$|^settings\.gradle$" | head -1
)
[ -z "$CODE_CHANGED" ] && exit 0

# ── 빌드 도구 감지 ───────────────────────────────────────────────────────────
if [ -f "./gradlew" ]; then
    COMPILE_CMD="./gradlew compileJava compileTestJava"
    TEST_CMD="./gradlew test"
elif [ -f "./mvnw" ]; then
    COMPILE_CMD="./mvnw compile test-compile -q"
    TEST_CMD="./mvnw test"
else
    exit 0  # Gradle도 Maven도 없으면 통과
fi

# ── 컴파일 검증 ──────────────────────────────────────────────────────────────
COMPILE_OUTPUT=$($COMPILE_CMD 2>&1)
COMPILE_EXIT=$?

if [ $COMPILE_EXIT -ne 0 ]; then
    echo "" >&2
    echo "❌ [stop-build-check] 컴파일 실패 — 작업 완료가 차단되었습니다." >&2
    echo "" >&2
    echo "$COMPILE_OUTPUT" | grep -E "error:|^\s+\^|ERROR" | head -40 >&2
    echo "" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "▶  컴파일 오류를 수정한 뒤 다시 완료하세요." >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    exit 2
fi

# ── 테스트 검증 (컴파일 성공 시에만) ─────────────────────────────────────────
TEST_OUTPUT=$($TEST_CMD 2>&1)
TEST_EXIT=$?

if [ $TEST_EXIT -ne 0 ]; then
    echo "" >&2
    echo "❌ [stop-build-check] 테스트 실패 — 작업 완료가 차단되었습니다." >&2
    echo "" >&2
    echo "$TEST_OUTPUT" | grep -E "FAILED|> Task|tests were|Exception" | head -30 >&2
    echo "" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "▶  실패한 테스트를 수정한 뒤 다시 완료하세요." >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    exit 2
fi

# ── 위험 파일 변경 감지 (코드 리뷰 권장) ─────────────────────────────────────
# - migration/                  : DB 스키마 변경
# - /security/ / Security*.java : 인증·인가 설정
# - /auth/ / Auth*.java         : 인증 로직
# - /payment/ / Payment*.java   : 결제 로직
# - .github/workflows/          : CI/CD 파이프라인
CHANGED_FILES=$(
    { git diff --name-only HEAD 2>/dev/null
      git ls-files --others --exclude-standard 2>/dev/null; } | sort -u
)

if [ -n "$CHANGED_FILES" ]; then
    RISKY_FILES=$(echo "$CHANGED_FILES" | grep -iE \
        "migration/|/security/|Security[A-Za-z]+\.(java|kt)|/auth/|Auth[A-Za-z]+\.(java|kt)|/payment/|Payment[A-Za-z]+\.(java|kt)|\.github/workflows/")
    if [ -n "$RISKY_FILES" ]; then
        echo "" >&2
        echo "⚠️  [stop-build-check] 위험도 높은 파일이 변경되었습니다 — /code-review 실행을 권장합니다." >&2
        echo "" >&2
        echo "$RISKY_FILES" | sed 's/^/    /' >&2
        echo "" >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo "▶  /code-review 를 실행하고 리뷰 완료 후 완료 처리하세요." >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    fi
fi

exit 0
