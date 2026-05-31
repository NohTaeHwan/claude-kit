#!/bin/bash
# PreToolUse 훅: Edit/Write 도구로 민감 설정 파일 수정 시 사용자 확인 요구 (전역)
#
# 보호 대상:
#   - application*.yml       (Spring Boot 설정)
#   - .env, .env.*           (환경변수)
#   - .claude/settings.json  (하네스 설정)
#   - .claude/hooks/*.sh     (훅 스크립트)
#
# 승인 흐름:
#   1. 훅이 민감 파일 감지 → exit 2로 차단
#   2. Claude가 사용자에게 수정 내용·목적 설명 후 승인 요청
#   3. 사용자 승인 후 Claude가 Bash로 일회성 승인 토큰 생성:
#      echo "<file_path>" > "$HOME/.claude/.file_edit_approved" # user-confirmed
#   4. 훅이 토큰 확인 후 삭제하고 Edit/Write 통과

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" \
    2>/dev/null || echo "")

# Edit 또는 Write 도구만 처리
if [ "$TOOL_NAME" != "Edit" ] && [ "$TOOL_NAME" != "Write" ]; then
    exit 0
fi

FILE_PATH=$(echo "$INPUT" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" \
    2>/dev/null || echo "")

[ -z "$FILE_PATH" ] && exit 0

BASENAME=$(basename "$FILE_PATH")
MATCHED_DESC=""

# ── 민감 파일 패턴 체크 ──────────────────────────────────────────────
# application*.yml (Spring Boot 설정)
if echo "$BASENAME" | grep -Eq "^application.*\.yml$"; then
    MATCHED_DESC="Spring Boot 설정 파일"
# .env 또는 .env.* (환경변수)
elif echo "$BASENAME" | grep -Eq "^\.env(\..*)?$"; then
    MATCHED_DESC="환경변수 파일"
# .claude/settings.json (하네스 설정)
elif echo "$FILE_PATH" | grep -q "\.claude/settings\.json"; then
    MATCHED_DESC="Claude 하네스 설정 파일"
# .claude/hooks/*.sh (훅 스크립트)
elif echo "$FILE_PATH" | grep -q "\.claude/hooks/"; then
    MATCHED_DESC="하네스 훅 스크립트"
fi

[ -z "$MATCHED_DESC" ] && exit 0

# ── 일회성 승인 토큰 체크 ────────────────────────────────────────────
APPROVAL_FILE="$HOME/.claude/.file_edit_approved"

if [ -f "$APPROVAL_FILE" ]; then
    APPROVED_PATH=$(cat "$APPROVAL_FILE" 2>/dev/null | tr -d '\n')
    if [ "$APPROVED_PATH" = "$FILE_PATH" ]; then
        rm -f "$APPROVAL_FILE"
        exit 0
    fi
fi

# ── 차단 메시지 (stderr → Claude에게 전달) ──────────────────────────
echo "" >&2
echo "⚠️  [file-guard] 민감 설정 파일 수정이 감지되어 실행이 차단되었습니다." >&2
echo "" >&2
echo "   유형: $MATCHED_DESC" >&2
echo "   파일: $FILE_PATH" >&2
echo "" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "▶  사용자에게 수정 내용과 목적을 설명하고 승인을 받으세요." >&2
echo "   승인 후 아래 명령어를 실행하고 Edit/Write를 재시도하세요:" >&2
echo "" >&2
printf '   echo "%s" > "$HOME/.claude/.file_edit_approved" # user-confirmed\n' "$FILE_PATH" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "" >&2
exit 2