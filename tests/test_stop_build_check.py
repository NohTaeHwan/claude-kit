#!/usr/bin/env python3
"""Spring Boot Stop Hook 회귀 테스트."""
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
HOOK_SOURCE = REPO_ROOT / 'templates' / 'spring-boot' / 'hooks' / 'stop_build_check.sh'
REVIEW_SOURCE = REPO_ROOT / 'templates' / 'spring-boot' / 'review' / 'review_guide.py'
RULES_SOURCE = REPO_ROOT / 'templates' / 'spring-boot' / 'review' / 'review-rules.json'


class TestStopBuildCheck(unittest.TestCase):

    def test_duplicate_modified_file_runs_test_class_once(self):
        with tempfile.TemporaryDirectory() as tmp:
            project_root = Path(tmp)
            hook_dir = project_root / '.claude' / 'hooks'
            hook_dir.mkdir(parents=True)
            hook_path = hook_dir / 'stop_build_check.sh'
            shutil.copy2(HOOK_SOURCE, hook_path)

            main_file = project_root / 'src/main/java/com/example/UserController.java'
            test_file = project_root / 'src/test/java/com/example/UserControllerTest.java'
            main_file.parent.mkdir(parents=True)
            test_file.parent.mkdir(parents=True)
            main_file.write_text('class UserController {}\n', encoding='utf-8')
            test_file.write_text('class UserControllerTest {}\n', encoding='utf-8')

            marker = project_root / '.claude' / '.code_changed'
            marker.write_text(
                f'{main_file}\n{main_file}\n{main_file}\n',
                encoding='utf-8',
            )

            gradle_log = project_root / 'gradle-args.log'
            gradlew = project_root / 'gradlew'
            gradlew.write_text(
                '#!/bin/bash\nprintf "%s\\n" "$*" >> "$GRADLE_LOG"\nexit 0\n',
                encoding='utf-8',
            )
            gradlew.chmod(0o755)

            env = os.environ.copy()
            env['GRADLE_LOG'] = str(gradle_log)
            result = subprocess.run(
                [str(hook_path)],
                input=json.dumps({}),
                text=True,
                capture_output=True,
                env=env,
                cwd=project_root,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            calls = gradle_log.read_text(encoding='utf-8').splitlines()
            self.assertEqual(len(calls), 2)
            test_call = calls[1]
            self.assertEqual(test_call.count('--tests'), 1)
            self.assertEqual(
                test_call.count('com.example.UserControllerTest'),
                1,
            )

    def test_maven_test_list_has_no_trailing_comma(self):
        with tempfile.TemporaryDirectory() as tmp:
            project_root = Path(tmp)
            hook_dir = project_root / '.claude' / 'hooks'
            hook_dir.mkdir(parents=True)
            hook_path = hook_dir / 'stop_build_check.sh'
            shutil.copy2(HOOK_SOURCE, hook_path)

            main_file = project_root / 'src/main/java/com/example/UserController.java'
            test_file = project_root / 'src/test/java/com/example/UserControllerTest.java'
            main_file.parent.mkdir(parents=True)
            test_file.parent.mkdir(parents=True)
            main_file.write_text('class UserController {}\n', encoding='utf-8')
            test_file.write_text('class UserControllerTest {}\n', encoding='utf-8')

            marker = project_root / '.claude' / '.code_changed'
            marker.write_text(f'{main_file}\n{main_file}\n', encoding='utf-8')

            maven_log = project_root / 'maven-args.log'
            mvnw = project_root / 'mvnw'
            mvnw.write_text(
                '#!/bin/bash\nprintf "%s\\n" "$*" >> "$MAVEN_LOG"\nexit 0\n',
                encoding='utf-8',
            )
            mvnw.chmod(0o755)

            env = os.environ.copy()
            env['MAVEN_LOG'] = str(maven_log)
            result = subprocess.run(
                [str(hook_path)],
                input=json.dumps({}),
                text=True,
                capture_output=True,
                env=env,
                cwd=project_root,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            calls = maven_log.read_text(encoding='utf-8').splitlines()
            self.assertEqual(len(calls), 2)
            self.assertEqual(
                calls[1],
                'test -Dtest=com.example.UserControllerTest',
            )

    def test_distinct_files_mapping_to_same_test_are_deduplicated_in_order(self):
        with tempfile.TemporaryDirectory() as tmp:
            project_root = Path(tmp)
            hook_dir = project_root / '.claude' / 'hooks'
            hook_dir.mkdir(parents=True)
            hook_path = hook_dir / 'stop_build_check.sh'
            shutil.copy2(HOOK_SOURCE, hook_path)

            controller_main = project_root / 'src/main/java/com/example/UserController.java'
            controller_test = project_root / 'src/test/java/com/example/UserControllerTest.java'
            service_main = project_root / 'src/main/java/com/example/UserService.java'
            service_test = project_root / 'src/test/java/com/example/UserServiceTest.java'
            for path in (controller_main, controller_test, service_main, service_test):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(f'class {path.stem} {{}}\n', encoding='utf-8')

            marker = project_root / '.claude' / '.code_changed'
            marker.write_text(
                f'{controller_main}\n{controller_test}\n{service_main}\n{controller_main}\n',
                encoding='utf-8',
            )

            gradle_log = project_root / 'gradle-args.log'
            gradlew = project_root / 'gradlew'
            gradlew.write_text(
                '#!/bin/bash\nprintf "%s\\n" "$*" >> "$GRADLE_LOG"\nexit 0\n',
                encoding='utf-8',
            )
            gradlew.chmod(0o755)

            env = os.environ.copy()
            env['GRADLE_LOG'] = str(gradle_log)
            result = subprocess.run(
                [str(hook_path)], input=json.dumps({}), text=True,
                capture_output=True, env=env, cwd=project_root,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            calls = gradle_log.read_text(encoding='utf-8').splitlines()
            self.assertEqual(
                calls[1],
                'test --tests com.example.UserControllerTest '
                '--tests com.example.UserServiceTest',
            )

    def test_review_prompt_separates_hook_findings_from_agent_opinions(self):
        with tempfile.TemporaryDirectory() as tmp:
            project_root = Path(tmp)
            hook_dir = project_root / '.claude' / 'hooks'
            review_dir = project_root / '.claude' / 'review'
            hook_dir.mkdir(parents=True)
            review_dir.mkdir(parents=True)
            hook_path = hook_dir / 'stop_build_check.sh'
            shutil.copy2(HOOK_SOURCE, hook_path)
            shutil.copy2(REVIEW_SOURCE, review_dir / 'review_guide.py')
            shutil.copy2(RULES_SOURCE, review_dir / 'review-rules.json')

            main_file = project_root / 'src/main/java/com/example/UserController.java'
            test_file = project_root / 'src/test/java/com/example/UserControllerTest.java'
            main_file.parent.mkdir(parents=True)
            test_file.parent.mkdir(parents=True)
            main_file.write_text(
                '@GetMapping("/users")\npublic class UserController {}\n',
                encoding='utf-8',
            )
            test_file.write_text('class UserControllerTest {}\n', encoding='utf-8')
            (project_root / '.claude' / '.code_changed').write_text(
                f'{main_file}\n', encoding='utf-8',
            )

            gradlew = project_root / 'gradlew'
            gradlew.write_text('#!/bin/bash\nexit 0\n', encoding='utf-8')
            gradlew.chmod(0o755)

            result = subprocess.run(
                [str(hook_path)], input=json.dumps({}), text=True,
                capture_output=True, cwd=project_root,
            )

            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertIn('[Hook 자동 탐지 결과]', result.stderr)
            self.assertIn('[Agent 추가 검토 의견]', result.stderr)
            self.assertIn(
                'Hook 탐지 결과가 아닌 Agent의 추가 의견',
                result.stderr,
            )
            self.assertIn('추가 의견이 없으면', result.stderr)


if __name__ == '__main__':
    unittest.main(verbosity=2)
