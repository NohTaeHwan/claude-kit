#!/bin/bash
# claude-kit 설치 / 업데이트 스크립트
#
# 최초 설치: ./install.sh
# 이후 업데이트: git pull 후 settings.json이 바뀐 경우에만 ./install.sh 재실행

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"

echo "claude-kit 설치/업데이트 시작..."
echo ""

# ── 1. 훅 디렉토리 생성 ──────────────────────────────────────────────
mkdir -p "$HOOKS_DIR"

# ── 2. 심볼릭 링크 설정 (hooks + global-CLAUDE.md) ──────────────────
ln -sf "$REPO_DIR/core/hooks/pre_tool_use_confirm.sh" "$HOOKS_DIR/pre_tool_use_confirm.sh"
ln -sf "$REPO_DIR/core/hooks/pre_tool_use_file_guard.sh" "$HOOKS_DIR/pre_tool_use_file_guard.sh"
chmod +x "$HOOKS_DIR"/*.sh
ln -sf "$REPO_DIR/core/global-CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"

echo "[완료] 심볼릭 링크 설정"
echo "       hooks/  → $HOOKS_DIR"
echo "       CLAUDE.md → $CLAUDE_DIR/CLAUDE.md"

# ── 3. settings.json — HOME 경로 치환 후 UI 설정 보존하며 병합 ───────
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

python3 -c "
import json

with open('$REPO_DIR/core/settings.json') as f:
    content = f.read().replace('/YOUR_HOME/', '$HOME/')
    new = json.loads(content)

# 기존 settings.json이 있으면 UI 설정 보존 (theme, alwaysThinkingEnabled 등)
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

echo "[완료] settings.json 생성/업데이트"
echo "       경로: $SETTINGS_FILE"
echo ""
echo "claude-kit 설치/업데이트 완료!"