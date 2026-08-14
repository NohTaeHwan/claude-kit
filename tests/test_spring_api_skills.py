#!/usr/bin/env python3
"""Spring API Skill 구조와 설치 동작 테스트."""
import json
import re
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
TEMPLATE_ROOT = REPO_ROOT / "templates" / "spring-boot"
SKILLS_ROOT = TEMPLATE_ROOT / "skills"
INSTALLER = REPO_ROOT / "install.sh"

SKILL_NAMES = (
    "spring-api-create",
    "spring-api-update",
    "spring-api-delete",
)
SHARED_FILES = (
    "project-discovery.md",
    "tdd-workflow.md",
    "persistence-routing.md",
    "documentation-and-verification.md",
)
ALLOWED_FRONTMATTER_FIELDS = {
    "name",
    "description",
    "license",
    "compatibility",
    "metadata",
    "allowed-tools",
}
FORBIDDEN_PROJECT_SPECIFIC_TEXT = (
    "org.dev.hehe",
    "CommonException",
    "docs/dev_context.md",
    "docs/create_ddl.md",
    "ApiSpecification",
)
FORBIDDEN_DOCUMENT_EXPRESSIONS = (
    "## Overview",
    "## When to Use",
    "## Required Shared References",
    "## Workflow",
    "## Common Pitfalls",
    "## Verification Checklist",
    "특성화",
    "문서 동기화",
    "문서 이정표",
    "수직 확장",
    "하위 호환",
    "RED→GREEN",
    "RED → GREEN",
    "## 2. RED",
    "## 3. GREEN",
    "## 4. REFACTOR",
)
REQUIRED_TDD_EXPRESSIONS = (
    "실패하는 테스트 작성(RED)",
    "최소 구현으로 테스트 통과(GREEN)",
    "동작을 유지하며 코드 정리(REFACTOR)",
)


def read_frontmatter(path: Path) -> dict[str, str]:
    content = path.read_text(encoding="utf-8")
    if not content.startswith("---\n"):
        raise AssertionError(f"frontmatter must start at byte 0: {path}")
    parts = content.split("---\n", 2)
    if len(parts) != 3 or parts[0] != "":
        raise AssertionError(f"frontmatter is not closed: {path}")
    raw = parts[1]

    fields: dict[str, str] = {}
    for line in raw.splitlines():
        if not line or line[0].isspace() or ":" not in line:
            continue
        key, value = line.split(":", 1)
        fields[key.strip()] = value.strip().strip('"').strip("'")
    return fields


class TestSpringApiSkills(unittest.TestCase):

    def run_installer(self, project: Path, *options: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(INSTALLER), "--project", str(project), "spring-boot", *options],
            cwd=REPO_ROOT,
            text=True,
            capture_output=True,
            check=False,
        )

    def assert_skills_installed(self, project: Path) -> None:
        for name in SKILL_NAMES:
            installed = project / ".claude" / "skills" / name / "SKILL.md"
            source = SKILLS_ROOT / name / "SKILL.md"
            self.assertTrue(installed.is_file(), name)
            self.assertEqual(installed.read_bytes(), source.read_bytes(), name)
        for filename in SHARED_FILES:
            installed = project / ".claude" / "skills" / "spring-api-shared" / filename
            source = SKILLS_ROOT / "spring-api-shared" / filename
            self.assertTrue(installed.is_file(), filename)
            self.assertEqual(installed.read_bytes(), source.read_bytes(), filename)

    def test_skill_structure_uses_portable_frontmatter_and_shared_references(self):
        for name in SKILL_NAMES:
            skill_file = SKILLS_ROOT / name / "SKILL.md"
            self.assertTrue(skill_file.is_file(), skill_file)

            fields = read_frontmatter(skill_file)
            self.assertEqual(fields.get("name"), name)
            self.assertTrue(fields.get("description"))
            self.assertLessEqual(len(fields["description"]), 1024)
            self.assertTrue(set(fields).issubset(ALLOWED_FRONTMATTER_FIELDS), fields)
            if name in {"spring-api-update", "spring-api-delete"}:
                for excluded in ("WebFlux", "Kotlin", "GraphQL", "R2DBC"):
                    self.assertIn(excluded, fields["description"])

            content = skill_file.read_text(encoding="utf-8")
            self.assertIn("사용하지 않는다", content)
            for forbidden in FORBIDDEN_PROJECT_SPECIFIC_TEXT:
                self.assertNotIn(forbidden, content)

            references = re.findall(r"\.\./spring-api-shared/[^)`\s]+\.md", content)
            self.assertEqual(
                set(references),
                {f"../spring-api-shared/{filename}" for filename in SHARED_FILES},
                f"shared references differ: {name}",
            )
            for reference in references:
                self.assertTrue((skill_file.parent / reference).resolve().is_file(), reference)

        shared_dir = SKILLS_ROOT / "spring-api-shared"
        self.assertFalse((shared_dir / "SKILL.md").exists())
        for filename in SHARED_FILES:
            shared_file = shared_dir / filename
            self.assertTrue(shared_file.is_file(), shared_file)
            content = shared_file.read_text(encoding="utf-8")
            for forbidden in FORBIDDEN_PROJECT_SPECIFIC_TEXT:
                self.assertNotIn(forbidden, content)

        documentation = (SKILLS_ROOT / "spring-api-shared" / "documentation-and-verification.md").read_text(encoding="utf-8")
        self.assertIn("임시 검증용 API", documentation)
        self.assertIn("API 명세·문서 작성 규칙", documentation)

    def test_skill_documents_explain_tdd_terms_in_korean(self):
        documents = [
            *(SKILLS_ROOT / name / "SKILL.md" for name in SKILL_NAMES),
            *(SKILLS_ROOT / "spring-api-shared" / filename for filename in SHARED_FILES),
        ]

        for document in documents:
            content = document.read_text(encoding="utf-8")
            for expression in FORBIDDEN_DOCUMENT_EXPRESSIONS:
                self.assertNotIn(expression, content, f"{expression}: {document}")

        tdd_document = (SKILLS_ROOT / "spring-api-shared" / "tdd-workflow.md").read_text(encoding="utf-8")
        for expression in REQUIRED_TDD_EXPRESSIONS:
            self.assertIn(expression, tdd_document)

    def test_default_install_includes_skills_and_supports_space_in_path(self):
        with tempfile.TemporaryDirectory() as tmp:
            project = Path(tmp) / "project with space"
            project.mkdir()

            result = self.run_installer(project)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assert_skills_installed(project)
            self.assertTrue((project / "CLAUDE.md").is_file())
            hook = project / ".claude" / "hooks" / "stop_build_check.sh"
            self.assertTrue(hook.is_file())
            hook.write_text('#!/bin/bash\ntouch "$(dirname "$0")/executed"\n', encoding="utf-8")
            settings = json.loads((project / ".claude" / "settings.json").read_text(encoding="utf-8"))
            command = settings["hooks"]["Stop"][0]["hooks"][0]["command"]
            hook_result = subprocess.run(command, cwd=project, shell=True, text=True, capture_output=True)
            self.assertEqual(hook_result.returncode, 0, hook_result.stderr)
            self.assertTrue((hook.parent / "executed").exists())

    def test_full_install_quotes_shell_metacharacters_in_project_path(self):
        with tempfile.TemporaryDirectory() as tmp:
            project = Path(tmp) / "project 'quoted' & safe"
            project.mkdir()

            result = self.run_installer(project)

            self.assertEqual(result.returncode, 0, result.stderr)
            hook = project / ".claude" / "hooks" / "stop_build_check.sh"
            hook.write_text('#!/bin/bash\ntouch "$(dirname "$0")/executed"\n', encoding="utf-8")
            settings = json.loads((project / ".claude" / "settings.json").read_text(encoding="utf-8"))
            command = settings["hooks"]["Stop"][0]["hooks"][0]["command"]
            hook_result = subprocess.run(command, cwd=project, shell=True, text=True, capture_output=True)
            self.assertEqual(hook_result.returncode, 0, hook_result.stderr)
            self.assertTrue((hook.parent / "executed").exists())

    def test_hooks_only_does_not_install_skills(self):
        with tempfile.TemporaryDirectory() as tmp:
            project = Path(tmp)

            result = self.run_installer(project, "--hooks-only")

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse((project / ".claude" / "skills").exists())
            self.assertFalse((project / "CLAUDE.md").exists())
            self.assertTrue((project / ".claude" / "hooks" / "stop_build_check.sh").is_file())

    def test_skills_only_preserves_existing_claude_settings_and_hooks(self):
        with tempfile.TemporaryDirectory() as tmp:
            project = Path(tmp)
            claude_dir = project / ".claude"
            hooks_dir = claude_dir / "hooks"
            hooks_dir.mkdir(parents=True)
            (project / "CLAUDE.md").write_text("existing context\n", encoding="utf-8")
            (claude_dir / "settings.json").write_text('{"existing": true}\n', encoding="utf-8")
            (hooks_dir / "custom.sh").write_text("existing hook\n", encoding="utf-8")

            result = self.run_installer(project, "--skills-only")

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assert_skills_installed(project)
            self.assertEqual((project / "CLAUDE.md").read_text(encoding="utf-8"), "existing context\n")
            self.assertEqual(
                (claude_dir / "settings.json").read_text(encoding="utf-8"),
                '{"existing": true}\n',
            )
            self.assertEqual((hooks_dir / "custom.sh").read_text(encoding="utf-8"), "existing hook\n")
            self.assertFalse((hooks_dir / "stop_build_check.sh").exists())

    def test_skills_only_preserves_unrelated_existing_skill(self):
        with tempfile.TemporaryDirectory() as tmp:
            project = Path(tmp)
            custom = project / ".claude" / "skills" / "custom-skill" / "SKILL.md"
            custom.parent.mkdir(parents=True)
            custom.write_text("custom skill\n", encoding="utf-8")

            result = self.run_installer(project, "--skills-only")

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(custom.read_text(encoding="utf-8"), "custom skill\n")

    def test_skills_only_rejects_symlinked_target_tree(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            project = root / "project"
            outside = root / "outside"
            (project / ".claude").mkdir(parents=True)
            outside.mkdir()
            sentinel = outside / "sentinel"
            sentinel.write_text("unchanged\n", encoding="utf-8")
            (project / ".claude" / "skills").symlink_to(outside, target_is_directory=True)

            result = self.run_installer(project, "--skills-only")

            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(sentinel.read_text(encoding="utf-8"), "unchanged\n")
            self.assertFalse((outside / "spring-api-create").exists())

    def test_skills_only_reports_file_directory_collision(self):
        with tempfile.TemporaryDirectory() as tmp:
            project = Path(tmp)
            skills = project / ".claude" / "skills"
            skills.mkdir(parents=True)
            (skills / "spring-api-create").write_text("not a directory\n", encoding="utf-8")

            result = self.run_installer(project, "--skills-only")

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("오류", result.stdout + result.stderr)

    def test_skill_install_backs_up_existing_file_and_is_repeatable(self):
        with tempfile.TemporaryDirectory() as tmp:
            project = Path(tmp)
            target = project / ".claude" / "skills" / "spring-api-create" / "SKILL.md"
            target.parent.mkdir(parents=True)
            target.write_text("user skill\n", encoding="utf-8")

            first = self.run_installer(project, "--skills-only")
            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertEqual(target.with_suffix(".md.bak").read_text(encoding="utf-8"), "user skill\n")
            installed_content = target.read_text(encoding="utf-8")

            second = self.run_installer(project, "--skills-only")
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertEqual(target.read_text(encoding="utf-8"), installed_content)
            self.assertEqual(target.with_suffix(".md.bak").read_text(encoding="utf-8"), installed_content)

    def test_readme_documents_skill_install_and_version(self):
        content = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn("--skills-only", content)
        self.assertIn("spring-api-create", content)
        self.assertIn("spring-api-update", content)
        self.assertIn("spring-api-delete", content)
        self.assertIn("### v1.8.0", content)

    def test_spring_template_routes_api_work_to_three_skills(self):
        content = (TEMPLATE_ROOT / "CLAUDE.md").read_text(encoding="utf-8")
        for name in SKILL_NAMES:
            self.assertIn(name, content)
        self.assertIn("프로젝트 설정", content)
        self.assertIn("기존 구조", content)
        self.assertNotIn("Java 17+", content)
        self.assertIn("프로젝트에서 OpenAPI", content)
        self.assertIn("사용 중일 때만", content)


if __name__ == "__main__":
    unittest.main()
