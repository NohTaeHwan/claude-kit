#!/bin/bash
# PreToolUse 훅: Spring MVC Controller 변경 전 API Skill 호출 여부를 확인합니다.
#
# 적용 대상:
#   - src/main/java/**/**Controller.java
#   - Edit / Write 도구
#
# 동작 방식:
#   1. 현재 Claude Code 세션 transcript에서 API Skill 호출 또는 비대상 선언을 확인
#   2. 둘 다 없으면 Controller 변경을 차단
#   3. Claude가 작업 유형에 맞는 Skill을 먼저 읽고 재시도
#   4. 사용자가 명시적으로 승인한 경우 프로젝트별 일회성 토큰으로 우회 가능

set -u

INPUT=$(cat)

read_json_field() {
    local expression="$1"
    printf '%s' "$INPUT" | python3 -c \
        "import sys,json; d=json.load(sys.stdin); print($expression)" \
        2>/dev/null || true
}

TOOL_NAME=$(read_json_field "d.get('tool_name','')")

# Edit 또는 Write 도구만 처리
if [ "$TOOL_NAME" != "Edit" ] && [ "$TOOL_NAME" != "Write" ]; then
    exit 0
fi

FILE_PATH=$(read_json_field "d.get('tool_input',{}).get('file_path','')")

# Spring main source의 Controller만 처리. 테스트 Controller나 다른 언어는 대상이 아님.
if ! printf '%s' "$FILE_PATH" | grep -Eq '(^|/)src/main/java/.*/[^/]*Controller\.java$'; then
    exit 0
fi

PROJECT_ROOT=$(git -C "$(dirname "$FILE_PATH")" rev-parse --show-toplevel 2>/dev/null || pwd)
APPROVAL_FILE="$PROJECT_ROOT/.claude/.api_skill_routing_approved"

# 사용자 승인 후 생성된 일회성 토큰 확인. 토큰 형식: 절대경로
if [ -f "$APPROVAL_FILE" ]; then
    APPROVED_PATH=$(tr -d '\n' < "$APPROVAL_FILE" 2>/dev/null || true)
    if [ "$APPROVED_PATH" = "$FILE_PATH" ]; then
        rm -f "$APPROVAL_FILE"
        exit 0
    fi
fi

TRANSCRIPT_PATH=$(read_json_field "d.get('transcript_path','')")

# Claude Code가 transcript 경로를 제공하지 않으면 안전하게 차단한다.
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    TRANSCRIPT_STATUS="현재 세션 transcript를 확인할 수 없습니다."
else
    TRANSCRIPT_STATUS=""
    FOUND_SKILL=""
    for skill in spring-api-create spring-api-update spring-api-delete; do
        # 일반 대화 문장의 Skill 이름이 아니라 같은 JSON record의 실제
        # Skill tool_use만 인정한다.
        if python3 - "$TRANSCRIPT_PATH" "$skill" <<'PY'
import json
import sys

path, skill = sys.argv[1:]
for raw_line in open(path, encoding="utf-8"):
    try:
        record = json.loads(raw_line)
    except (json.JSONDecodeError, UnicodeDecodeError):
        continue
    text = json.dumps(record, ensure_ascii=False).lower()
    if skill.lower() in text and (
        '"type": "tool_use"' in text
        or '"tool_name": "skill"' in text
        or '"name": "skill"' in text
    ):
        raise SystemExit(0)
raise SystemExit(1)
PY
        then
            FOUND_SKILL="$skill"
            break
        fi
    done
    if [ -n "$FOUND_SKILL" ]; then
        exit 0
    fi
    # API 범위 밖의 Controller 변경은 Assistant가 명시적으로 선언하면
    # 사용자 승인 없이 통과시킨다. 사용자 메시지의 동일 문구는 인정하지 않는다.
    if python3 - "$TRANSCRIPT_PATH" <<'PY'
import json
import sys

path = sys.argv[1]
for raw_line in open(path, encoding="utf-8"):
    try:
        record = json.loads(raw_line)
    except (json.JSONDecodeError, UnicodeDecodeError):
        continue
    message = record.get("message", record)
    if not isinstance(message, dict) or message.get("role") != "assistant":
        continue
    text = json.dumps(message, ensure_ascii=False)
    if "Skill 매칭: 해당 없음" in text:
        raise SystemExit(0)
raise SystemExit(1)
PY
    then
        exit 0
    fi
    TRANSCRIPT_STATUS="현재 세션에서 spring-api-create/update/delete 호출 흔적을 찾지 못했습니다."
fi

echo "" >&2
echo "⚠️  [api-skill-routing] Controller 변경이 차단되었습니다." >&2
echo "" >&2
echo "   파일: $FILE_PATH" >&2
echo "   사유: $TRANSCRIPT_STATUS" >&2
echo "" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "▶  구현 전에 작업 유형에 맞는 Skill을 먼저 읽고 다음 문구를 출력하세요:" >&2
echo "   Skill 매칭: spring-api-create | spring-api-update | spring-api-delete" >&2
echo "" >&2
echo "   API 작업이 아니면 다음 문구를 먼저 출력하세요:" >&2
echo "   Skill 매칭: 해당 없음 (API 작업 아님)" >&2
echo "" >&2
echo "   API 작업이면 해당 Skill을 호출한 뒤 Controller Edit/Write를 재시도하세요." >&2
echo "   정말 Skill을 적용할 수 없는 예외 상황이면 사용자 승인을 받고 아래 토큰을 생성하세요:" >&2
printf '   printf %s "%s" > "%s" # user-confirmed\n' "$FILE_PATH" "$APPROVAL_FILE" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "" >&2
exit 2
