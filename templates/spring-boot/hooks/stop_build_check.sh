#!/bin/bash
# Stop 훅: 작업 완료 전 컴파일·테스트 자동 검증
#
# 동작 방식:
#   1. 이번 턴에 Claude가 수정한 파일 목록을 마커 파일에서 읽음
#   2. 마커 없으면 즉시 통과 (코드 수정 없는 턴)
#   3. 컴파일 실패 시 exit 2로 차단
#   4. 수정된 파일에 대응하는 테스트 클래스만 실행 (전체 테스트 X)
#   5. 테스트 실패 시 exit 2로 차단
#   6. stop_hook_active = true이면 재시작된 세션이므로 즉시 통과 (무한 루프 방지)

INPUT=$(cat)

# 무한 루프 방지 — 훅으로 재시작된 세션은 즉시 통과
HOOK_ACTIVE=$(echo "$INPUT" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(d.get('stop_hook_active', False))" \
    2>/dev/null || echo "False")
[ "$HOOK_ACTIVE" = "True" ] && exit 0

# ── 코드 변경 마커 확인 ───────────────────────────────────────────────────────
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
MARKER_FILE="$PROJECT_ROOT/.claude/.code_changed"

[ ! -f "$MARKER_FILE" ] && exit 0

MODIFIED_FILES=$(cat "$MARKER_FILE")
rm -f "$MARKER_FILE"

cd "$PROJECT_ROOT"

# ── 빌드 도구 감지 ───────────────────────────────────────────────────────────
if [ -f "./gradlew" ]; then
    COMPILE_CMD="./gradlew compileJava compileTestJava"
    BUILD_TOOL="gradle"
elif [ -f "./mvnw" ]; then
    COMPILE_CMD="./mvnw compile test-compile -q"
    BUILD_TOOL="maven"
else
    exit 0
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

# ── 테스트 대상 결정 (수정 파일 → 대응 테스트 클래스) ──────────────────────────
TEST_CLASSES=""
NOT_FOUND_LOG=""

while IFS= read -r abs_file; do
    rel_file="${abs_file#$PROJECT_ROOT/}"
    test_file=""

    if echo "$rel_file" | grep -qE "^src/main/java/.*\.(java|kt)$"; then
        candidate=$(echo "$rel_file" \
            | sed 's|^src/main/java/|src/test/java/|' \
            | sed 's|\.java$|Test.java|' \
            | sed 's|\.kt$|Test.kt|')
        if [ -f "$candidate" ]; then
            test_file="$candidate"
        else
            NOT_FOUND_LOG="$NOT_FOUND_LOG\n    $rel_file\n    → 탐색: $candidate (없음)"
        fi
    elif echo "$rel_file" | grep -qE "^src/test/java/.*\.(java|kt)$"; then
        [ -f "$rel_file" ] && test_file="$rel_file"
    fi

    if [ -n "$test_file" ]; then
        class_name=$(echo "$test_file" \
            | sed 's|^src/test/java/||' \
            | sed 's|\.java$||' \
            | sed 's|\.kt$||' \
            | tr '/' '.')
        TEST_CLASSES="$TEST_CLASSES $class_name"
    fi
done <<< "$MODIFIED_FILES"

# 대응 테스트가 없으면 탐색 결과 보여주고 건너뜀
if [ -z "$TEST_CLASSES" ]; then
    echo "" >&2
    echo "ℹ️  [stop-build-check] 컴파일 통과. 테스트를 건너뜁니다." >&2
    echo "" >&2
    printf "%b\n" "$NOT_FOUND_LOG" >&2
    echo "" >&2
    exit 0
fi

echo "" >&2
echo "🔍 [stop-build-check] 대응 테스트 실행 중..." >&2
echo "$TEST_CLASSES" | tr ' ' '\n' | grep -v '^$' | sed 's/^/    /' >&2
echo "" >&2

# ── 테스트 실행 (대응 클래스만 타겟) ─────────────────────────────────────────
if [ "$BUILD_TOOL" = "gradle" ]; then
    TEST_ARGS=$(echo "$TEST_CLASSES" | xargs -n1 echo "--tests" | tr '\n' ' ')
    TEST_CMD="./gradlew test $TEST_ARGS"
else
    MAVEN_TESTS=$(echo "$TEST_CLASSES" | tr ' ' ',' | sed 's/^,//')
    TEST_CMD="./mvnw test -Dtest=$MAVEN_TESTS"
fi

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

echo "" >&2
echo "✅ [stop-build-check] 테스트 통과" >&2
echo "" >&2
echo "$TEST_CLASSES" | tr ' ' '\n' | grep -v '^$' | sed 's/^/    /' >&2
echo "" >&2

# ── 위험 파일 변경 감지 (코드 리뷰 권장) ─────────────────────────────────────
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
