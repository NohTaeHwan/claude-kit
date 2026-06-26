#!/bin/bash
# PreToolUse 훅: 확인 필요 명령어를 차단하고 사용자 승인을 요구합니다.
#
# 동작 방식:
#   1. Bash 명령어가 확인 필요 패턴에 해당하면 exit 2로 차단
#   2. Claude가 에러 메시지를 읽고 사용자에게 목적·영향을 설명 후 승인 요청
#   3. 사용자 승인 후 Claude는 명령어 끝에 '# user-confirmed'를 붙여 재시도
#   4. 훅이 '# user-confirmed'를 감지하면 통과 (exit 0)

INPUT=$(cat)

# Bash 도구 호출만 처리
TOOL_NAME=$(echo "$INPUT" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" \
    2>/dev/null || echo "")

[ "$TOOL_NAME" != "Bash" ] && exit 0

COMMAND=$(echo "$INPUT" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" \
    2>/dev/null || echo "")

# '# user-confirmed' 주석이 있으면 사용자 승인 완료 — 통과
if echo "$COMMAND" | grep -q "# user-confirmed"; then
    exit 0
fi

# ── 확인 필요 패턴 체크 ──────────────────────────────────────
MATCHED_DESC=""

if echo "$COMMAND" | grep -iEq "DELETE[[:space:]]+FROM"; then
    MATCHED_DESC="SQL DELETE — 데이터 삭제"
elif echo "$COMMAND" | grep -iEq "INSERT[[:space:]]+INTO"; then
    MATCHED_DESC="SQL INSERT — 데이터 삽입"
elif echo "$COMMAND" | grep -iEq "UPDATE[[:space:]].+[[:space:]]SET[[:space:]]"; then
    MATCHED_DESC="SQL UPDATE — 데이터 수정"
elif echo "$COMMAND" | grep -iEq "ALTER[[:space:]]+TABLE"; then
    MATCHED_DESC="DDL ALTER TABLE — 스키마 변경"
elif echo "$COMMAND" | grep -iEq "git[[:space:]]+rebase"; then
    MATCHED_DESC="git rebase — 히스토리 재작성"
elif echo "$COMMAND" | grep -iEq "(^|[[:space:]]|--)force([[:space:]]|$)"; then
    MATCHED_DESC="force 옵션 — 강제 실행"
elif echo "$COMMAND" | grep -iEq "git[[:space:]]+stash"; then
    MATCHED_DESC="git stash — 미커밋 변경사항 임시 저장 (잘못 처리 시 작업물 유실 위험)"
fi

# ── 패턴 매칭 시 차단 (메시지는 stderr로 출력 — 하네스가 stderr를 Claude에게 전달) ──
if [ -n "$MATCHED_DESC" ]; then
    echo "" >&2
    echo "⚠️  [confirm-required] 확인 필요 명령어가 감지되어 실행이 차단되었습니다." >&2
    echo "" >&2
    echo "   유형:   $MATCHED_DESC" >&2
    echo "   명령어: $COMMAND" >&2
    echo "" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "▶  사용자에게 이 명령어의 목적과 영향을 설명하고 승인을 받으세요." >&2
    echo "   승인 후, 명령어 끝에 '# user-confirmed' 주석을 추가하여 재시도하세요." >&2
    echo "" >&2
    echo "   예시: mysql -e \"DELETE FROM tb_test WHERE id=1\" # user-confirmed" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2
    exit 2
fi

exit 0