#!/bin/bash
set -e

# claude-kit 설치 / 업데이트 스크립트
#
# 전역 설치:     ./install.sh
# 프로젝트 설치: ./install.sh --project /path/to/project spring-boot
#               ./install.sh --project /path/to/project vue
#               ./install.sh --project /path/to/project vue --hooks-only   ← CLAUDE.md 제외, 훅·설정만 복사
#               ./install.sh --project /path/to/project spring-boot --skills-only ← 기존 Context·훅 유지, Skill만 복사

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

die() {
    echo "오류: $*" >&2
    exit 1
}

# ── 백업 함수 (실제 파일인 경우에만 — 심볼릭 링크·없는 파일은 건너뜀) ──────
backup_if_exists() {
    local file="$1"
    if [ -f "$file" ] && [ ! -L "$file" ]; then
        cp "$file" "${file}.bak" || die "백업에 실패했습니다 — $file"
        echo "[백업] $(basename "$file") → $(basename "$file").bak"
    fi
}

ensure_directory() {
    local directory="$1"
    if [ -L "$directory" ]; then
        die "심볼릭 링크 대상 디렉터리는 덮어쓰지 않습니다 — $directory"
    fi
    if [ -e "$directory" ] && [ ! -d "$directory" ]; then
        die "디렉터리가 필요한 위치에 다른 파일이 있습니다 — $directory"
    fi
    mkdir -p "$directory" || die "디렉터리를 만들 수 없습니다 — $directory"
}

safe_copy_file() {
    local source="$1"
    local target="$2"
    if [ -L "$source" ]; then
        die "템플릿의 심볼릭 링크는 복사하지 않습니다 — $source"
    fi
    if [ -L "$target" ]; then
        die "심볼릭 링크 대상 파일은 덮어쓰지 않습니다 — $target"
    fi
    if [ -d "$target" ]; then
        die "파일이 필요한 위치에 디렉터리가 있습니다 — $target"
    fi
    ensure_directory "$(dirname "$target")"
    backup_if_exists "$target"
    cp "$source" "$target" || die "파일 복사에 실패했습니다 — $target"
}

# ── 디렉토리 복사 함수 (기존 파일은 개별 백업) ──────────────────────────────
copy_tree_with_backups() {
    local source_dir="$1"
    local target_dir="$2"
    local source
    local target

    ensure_directory "$target_dir"
    for source in "$source_dir/"* "$source_dir"/.[!.]* "$source_dir"/..?*; do
        [ -e "$source" ] || [ -L "$source" ] || continue
        if [ -L "$source" ]; then
            die "템플릿의 심볼릭 링크는 복사하지 않습니다 — $source"
        fi
        target="$target_dir/$(basename "$source")"
        if [ -d "$source" ]; then
            copy_tree_with_backups "$source" "$target"
        else
            safe_copy_file "$source" "$target"
            echo "[완료] $(basename "$source") → $target_dir/"
        fi
    done
}

# ── 인자 파싱 ─────────────────────────────────────────────────────────────────
if [ "${1:-}" = "--project" ]; then

    # ── 프로젝트 설치 ────────────────────────────────────────────────────────
    PROJECT_DIR="${2:-}"
    TEMPLATE="${3:-}"

    INSTALL_MODE="full"
    case "${4:-}" in
        "") ;;
        --hooks-only) INSTALL_MODE="hooks" ;;
        --skills-only) INSTALL_MODE="skills" ;;
        *)
            echo "오류: 지원하지 않는 옵션입니다 — ${4:-}"
            echo "사용법: ./install.sh --project /path/to/project [spring-boot|vue] [--hooks-only|--skills-only]"
            exit 1
            ;;
    esac

    if [ -n "${5:-}" ]; then
        echo "오류: 프로젝트 설치 옵션은 하나만 지정할 수 있습니다."
        exit 1
    fi

    if [ -z "$PROJECT_DIR" ] || [ -z "$TEMPLATE" ]; then
        echo "사용법: ./install.sh --project /path/to/project [spring-boot|vue] [--hooks-only|--skills-only]"
        exit 1
    fi

    if [ ! -d "$PROJECT_DIR" ]; then
        echo "오류: 디렉토리가 존재하지 않습니다 — $PROJECT_DIR"
        exit 1
    fi

    PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd -P)"
    if [ -L "$PROJECT_DIR/.claude" ]; then
        die "프로젝트 .claude 디렉터리가 심볼릭 링크입니다 — $PROJECT_DIR/.claude"
    fi

    TEMPLATE_DIR="$REPO_DIR/templates/$TEMPLATE"
    if [ ! -d "$TEMPLATE_DIR" ]; then
        echo "오류: 지원하지 않는 템플릿입니다 — $TEMPLATE"
        echo "사용 가능한 템플릿: spring-boot, vue"
        exit 1
    fi

    if [ "$INSTALL_MODE" = "skills" ] && [ ! -d "$TEMPLATE_DIR/skills" ]; then
        echo "오류: Skill을 제공하지 않는 템플릿입니다 — $TEMPLATE"
        exit 1
    fi

    echo "[$TEMPLATE] 프로젝트 설치 시작: $PROJECT_DIR"
    echo ""

    # CLAUDE.md 복사 (전체 설치에서만)
    if [ "$INSTALL_MODE" = "full" ]; then
        safe_copy_file "$TEMPLATE_DIR/CLAUDE.md" "$PROJECT_DIR/CLAUDE.md"
        echo "[완료] CLAUDE.md → $PROJECT_DIR/CLAUDE.md"
    else
        echo "[건너뜀] CLAUDE.md (--$INSTALL_MODE-only 모드)"
    fi

    # settings.json + hooks/ 복사 (전체 또는 hooks-only)
    if [ "$INSTALL_MODE" != "skills" ] && [ -f "$TEMPLATE_DIR/settings.json" ]; then
        ensure_directory "$PROJECT_DIR/.claude/hooks"
        if [ -L "$PROJECT_DIR/.claude/settings.json" ]; then
            die "심볼릭 링크 settings 파일은 덮어쓰지 않습니다 — $PROJECT_DIR/.claude/settings.json"
        fi
        if [ -d "$PROJECT_DIR/.claude/settings.json" ]; then
            die "settings 파일 위치에 디렉터리가 있습니다 — $PROJECT_DIR/.claude/settings.json"
        fi
        backup_if_exists "$PROJECT_DIR/.claude/settings.json"
        python3 -c '
import json
import os
import shlex
import sys

source, target, project = sys.argv[1:]
with open(source, encoding="utf-8") as file:
    settings = json.load(file)

def rewrite(value):
    if isinstance(value, dict):
        return {key: rewrite(item) for key, item in value.items()}
    if isinstance(value, list):
        return [rewrite(item) for item in value]
    if isinstance(value, str) and value.startswith("bash .claude/hooks/"):
        relative_path = value[len("bash "):]
        absolute_path = os.path.join(project, relative_path)
        return "bash " + shlex.quote(absolute_path)
    return value

with open(target, "w", encoding="utf-8") as file:
    json.dump(rewrite(settings), file, indent=2, ensure_ascii=False)
    file.write("\n")
' "$TEMPLATE_DIR/settings.json" "$PROJECT_DIR/.claude/settings.json" "$PROJECT_DIR" || die "settings.json 생성에 실패했습니다."
        echo "[완료] settings.json → $PROJECT_DIR/.claude/settings.json"
    fi

    if [ "$INSTALL_MODE" != "skills" ] && [ -d "$TEMPLATE_DIR/hooks" ]; then
        ensure_directory "$PROJECT_DIR/.claude/hooks"
        for hook in "$TEMPLATE_DIR/hooks/"*.sh; do
            [ -f "$hook" ] || continue
            hook_name=$(basename "$hook")
            safe_copy_file "$hook" "$PROJECT_DIR/.claude/hooks/$hook_name"
            chmod +x "$PROJECT_DIR/.claude/hooks/$hook_name"
            echo "[완료] $hook_name → $PROJECT_DIR/.claude/hooks/"
        done
    fi

    # review/ 디렉토리 복사 (전체 또는 hooks-only)
    if [ "$INSTALL_MODE" != "skills" ] && [ -d "$TEMPLATE_DIR/review" ]; then
        ensure_directory "$PROJECT_DIR/.claude/review"
        for review_file in "$TEMPLATE_DIR/review/"*; do
            [ -f "$review_file" ] || continue
            review_name=$(basename "$review_file")
            safe_copy_file "$review_file" "$PROJECT_DIR/.claude/review/$review_name"
            echo "[완료] $review_name → $PROJECT_DIR/.claude/review/"
        done
    fi

    # skills/ 복사 (전체 또는 skills-only, 다른 프로젝트 Skill은 유지)
    if [ "$INSTALL_MODE" != "hooks" ] && [ -d "$TEMPLATE_DIR/skills" ]; then
        copy_tree_with_backups "$TEMPLATE_DIR/skills" "$PROJECT_DIR/.claude/skills"
    fi

    echo ""
    echo "[$TEMPLATE] 프로젝트 설치 완료!"
    if [ "$INSTALL_MODE" = "full" ]; then
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
