#!/usr/bin/env python3
"""Spring API Skill 라우팅 PreToolUse Hook 회귀 테스트."""
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from typing import Optional


REPO_ROOT = Path(__file__).resolve().parents[1]
HOOK_SOURCE = REPO_ROOT / "templates/spring-boot/hooks/pre_tool_use_require_api_skill.sh"


class TestRequireApiSkillHook(unittest.TestCase):
    def run_hook(self, project_root: Path, file_path: Path, transcript_path: Optional[Path] = None):
        payload = {
            "tool_name": "Edit",
            "tool_input": {"file_path": str(file_path)},
        }
        if transcript_path is not None:
            payload["transcript_path"] = str(transcript_path)
        hook = project_root / ".claude/hooks/pre_tool_use_require_api_skill.sh"
        return subprocess.run(
            [str(hook)],
            input=json.dumps(payload),
            text=True,
            capture_output=True,
            cwd=project_root,
        )

    def setUp_project(self):
        tmp = tempfile.TemporaryDirectory()
        project = Path(tmp.name)
        hook = project / ".claude/hooks/pre_tool_use_require_api_skill.sh"
        hook.parent.mkdir(parents=True)
        shutil.copy2(HOOK_SOURCE, hook)
        hook.chmod(0o755)
        return tmp, project

    def test_controller_change_is_blocked_without_skill_trace(self):
        tmp, project = self.setUp_project()
        try:
            controller = project / "src/main/java/com/example/UserController.java"
            controller.parent.mkdir(parents=True)
            transcript = project / "transcript.jsonl"
            transcript.write_text('{"type":"assistant","message":"일반 분석"}\n', encoding="utf-8")

            result = self.run_hook(project, controller, transcript)

            self.assertEqual(result.returncode, 2)
            self.assertIn("api-skill-routing", result.stderr)
            self.assertIn("spring-api-create/update/delete", result.stderr)
        finally:
            tmp.cleanup()

    def test_controller_change_passes_when_current_transcript_contains_api_skill(self):
        tmp, project = self.setUp_project()
        try:
            controller = project / "src/main/java/com/example/UserController.java"
            controller.parent.mkdir(parents=True)
            transcript = project / "transcript.jsonl"
            transcript.write_text(
                '{"type":"tool_use","name":"Skill","input":{"skill":"spring-api-create"}}\n',
                encoding="utf-8",
            )

            result = self.run_hook(project, controller, transcript)

            self.assertEqual(result.returncode, 0, result.stderr)
        finally:
            tmp.cleanup()

    def test_non_api_controller_change_passes_after_assistant_declaration(self):
        tmp, project = self.setUp_project()
        try:
            controller = project / "src/main/java/com/example/UserController.java"
            controller.parent.mkdir(parents=True)
            transcript = project / "transcript.jsonl"
            transcript.write_text(
                '{"message":{"role":"assistant","content":"Skill 매칭: 해당 없음 (API 작업 아님)"}}\n',
                encoding="utf-8",
            )

            result = self.run_hook(project, controller, transcript)

            self.assertEqual(result.returncode, 0, result.stderr)
        finally:
            tmp.cleanup()

    def test_user_message_does_not_count_as_non_api_declaration(self):
        tmp, project = self.setUp_project()
        try:
            controller = project / "src/main/java/com/example/UserController.java"
            controller.parent.mkdir(parents=True)
            transcript = project / "transcript.jsonl"
            transcript.write_text(
                '{"message":{"role":"user","content":"Skill 매칭: 해당 없음 (API 작업 아님)"}}\n',
                encoding="utf-8",
            )

            result = self.run_hook(project, controller, transcript)

            self.assertEqual(result.returncode, 2)
        finally:
            tmp.cleanup()

    def test_non_controller_source_change_passes_without_skill_trace(self):
        tmp, project = self.setUp_project()
        try:
            service = project / "src/main/java/com/example/UserService.java"
            service.parent.mkdir(parents=True)
            transcript = project / "transcript.jsonl"
            transcript.write_text("{}\n", encoding="utf-8")

            result = self.run_hook(project, service, transcript)

            self.assertEqual(result.returncode, 0, result.stderr)
        finally:
            tmp.cleanup()

    def test_approved_controller_change_consumes_one_time_token(self):
        tmp, project = self.setUp_project()
        try:
            controller = project / "src/main/java/com/example/UserController.java"
            controller.parent.mkdir(parents=True)
            approval = project / ".claude/.api_skill_routing_approved"
            approval.write_text(str(controller), encoding="utf-8")
            transcript = project / "transcript.jsonl"
            transcript.write_text("{}\n", encoding="utf-8")

            first = self.run_hook(project, controller, transcript)
            second = self.run_hook(project, controller, transcript)

            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertEqual(second.returncode, 2)
            self.assertFalse(approval.exists())
        finally:
            tmp.cleanup()


if __name__ == "__main__":
    unittest.main(verbosity=2)
