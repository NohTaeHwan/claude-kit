#!/bin/bash
# claude-kit 설치 / 업데이트 스크립트
#
# 전역 설치:     ./install.sh
# 프로젝트 설치: ./install.sh --project /path/to/project spring-boot
#               ./install.sh --project /path/to/project vue
#               ./install.sh --project /path/to/project vue --hooks-only   ← CLAUDE.md 제외, 훅·설정만 복사

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── 백업 함수 (실제 파일인 경우에만 — 심볼릭 링크·없는 파일은 건너뜀) ──────
backup_if_exists() {
    local file="$1"
    if [ -f "$file" ] && [ ! -L "$file" ]; then
        cp "$file" "${file}.bak"
        echo "[백업] $(basename "$file") → $(basename "$file").bak"
    fi
}

# ── 인자 파싱 ─────────────────────────────────────────────────────────────────
if [ "$1" = "--project" ]; then

    # ── 프로젝트 설치 ────────────────────────────────────────────────────────
    PROJECT_DIR="$2"
    TEMPLATE="$3"

    HOOKS_ONLY=0
    [ "$4" = "--hooks-only" ] && HOOKS_ONLY=1

    if [ -z "$PROJECT_DIR" ] || [ -z "$TEMPLATE" ]; then
        echo "사용법: ./install.sh --project /path/to/project [spring-boot|vue] [--hooks-only]"
        exit 1
    fi

    if [ ! -d "$PROJECT_DIR" ]; then
        echo "오류: 디렉토리가 존재하지 않습니다 — $PROJECT_DIR"
        exit 1
    fi

    TEMPLATE_DIR="$REPO_DIR/templates/$TEMPLATE"
    if [ ! -d "$TEMPLATE_DIR" ]; then
        echo "오류: 지원하지 않는 템플릿입니다 — $TEMPLATE"
        echo "사용 가능한 템플릿: spring-boot, vue"
        exit 1
    fi

    echo "[$TEMPLATE] 프로젝트 설치 시작: $PROJECT_DIR"
    echo ""

    # CLAUDE.md 복사 (--hooks-only 시 건너뜀)
    if [ $HOOKS_ONLY -eq 0 ]; then
        backup_if_exists "$PROJECT_DIR/CLAUDE.md"
        cp "$TEMPLATE_DIR/CLAUDE.md" "$PROJECT_DIR/CLAUDE.md"
        echo "[완료] CLAUDE.md → $PROJECT_DIR/CLAUDE.md"
    else
        echo "[건너뜀] CLAUDE.md (--hooks-only 모드)"
    fi

    # settings.json + hooks/ 복사 (템플릿에 있는 경우 자동 복사)
    if [ -f "$TEMPLATE_DIR/settings.json" ]; then
        mkdir -p "$PROJECT_DIR/.claude/hooks"
        backup_if_exists "$PROJECT_DIR/.claude/settings.json"
        cp "$TEMPLATE_DIR/settings.json" "$PROJECT_DIR/.claude/settings.json"
        # 훅 명령어를 절대경로로 치환 (CWD 무관하게 스크립트를 찾기 위해)
        sed -i '' "s|bash .claude/hooks/|bash $PROJECT_DIR/.claude/hooks/|g" "$PROJECT_DIR/.claude/settings.json"
        echo "[완료] settings.json → $PROJECT_DIR/.claude/settings.json"
    fi

    if [ -d "$TEMPLATE_DIR/hooks" ]; then
        mkdir -p "$PROJECT_DIR/.claude/hooks"
        for hook in "$TEMPLATE_DIR/hooks/"*.sh; do
            [ -f "$hook" ] || continue
            hook_name=$(basename "$hook")
            backup_if_exists "$PROJECT_DIR/.claude/hooks/$hook_name"
            cp "$hook" "$PROJECT_DIR/.claude/hooks/$hook_name"
            chmod +x "$PROJECT_DIR/.claude/hooks/$hook_name"
            echo "[완료] $hook_name → $PROJECT_DIR/.claude/hooks/"
        done
    fi

    # review/ 디렉토리 복사 (템플릿에 있는 경우)
    if [ -d "$TEMPLATE_DIR/review" ]; then
        mkdir -p "$PROJECT_DIR/.claude/review"
        for review_file in "$TEMPLATE_DIR/review/"*; do
            [ -f "$review_file" ] || continue
            review_name=$(basename "$review_file")
            backup_if_exists "$PROJECT_DIR/.claude/review/$review_name"
            cp "$review_file" "$PROJECT_DIR/.claude/review/$review_name"
            echo "[완료] $review_name → $PROJECT_DIR/.claude/review/"
        done
    fi

    echo ""
    echo "[$TEMPLATE] 프로젝트 설치 완료!"
    if [ $HOOKS_ONLY -eq 0 ]; then
        echo "CLAUDE.md를 열어 프로젝트에 맞게 내용을 채워주세요."
    fi

else

    # ── 전역 설치 ────────────────────────────────────────────────────────────
    CLAUDE_DIR="$HOME/.claude"
    HOOKS_DIR="$CLAUDE_DIR/hooks"

    echo "claude-kit 전역 설치/업데이트 시작..."
    echo ""

    mkdir -p "$HOOKS_DIR"

    # ── 깨진 심볼릭 링크 감지 (레포 이동 시 발생) ────────────────────────────
    BROKEN=0
    for link in "$HOOKS_DIR/pre_tool_use_confirm.sh" "$HOOKS_DIR/pre_tool_use_file_guard.sh" "$CLAUDE_DIR/CLAUDE.md"; do
        if [ -L "$link" ] && [ ! -e "$link" ]; then
            BROKEN=1
        fi
    done
    if [ $BROKEN -eq 1 ]; then
        echo "[감지] 깨진 심볼릭 링크가 있습니다 — 레포 위치가 변경된 것 같습니다."
        echo "       현재 경로($REPO_DIR)로 링크를 갱신합니다."
        echo ""
    fi

    # CLAUDE.md 백업 후 심볼릭 링크
    backup_if_exists "$CLAUDE_DIR/CLAUDE.md"
    ln -sf "$REPO_DIR/core/global-CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    echo "[완료] CLAUDE.md 심볼릭 링크 → $CLAUDE_DIR/CLAUDE.md"

    # 훅 백업 후 심볼릭 링크
    backup_if_exists "$HOOKS_DIR/pre_tool_use_confirm.sh"
    backup_if_exists "$HOOKS_DIR/pre_tool_use_file_guard.sh"
    ln -sf "$REPO_DIR/core/hooks/pre_tool_use_confirm.sh" "$HOOKS_DIR/pre_tool_use_confirm.sh"
    ln -sf "$REPO_DIR/core/hooks/pre_tool_use_file_guard.sh" "$HOOKS_DIR/pre_tool_use_file_guard.sh"
    chmod +x "$HOOKS_DIR"/*.sh
    echo "[완료] 훅 심볼릭 링크 → $HOOKS_DIR"

    # settings.json 백업 후 생성 (UI 설정 보존)
    SETTINGS_FILE="$CLAUDE_DIR/settings.json"
    backup_if_exists "$SETTINGS_FILE"

    python3 -c "
import json

with open('$REPO_DIR/core/settings.json') as f:
    content = f.read().replace('/YOUR_HOME/', '$HOME/')
    new = json.loads(content)

try:
    with open('$SETTINGS_FILE') as f:
        existing = json.load(f)
    for key in ['theme', 'alwaysThinkingEnabled', 'verboseOutput']:
        if key in existing:
            new[key] = existing[key]
except FileNotFoundError:
    pass

with open('$SETTINGS_FILE', 'w') as f:
    json.dump(new, f, indent=2, ensure_ascii=False)
"
    echo "[완료] settings.json → $SETTINGS_FILE"
    echo ""
    echo "claude-kit 전역 설치/업데이트 완료!"

fi
