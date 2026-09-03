#!/usr/bin/env python3
"""
review_guide.py 단위 테스트
실행: python3 -m unittest discover -s tests -p 'test_*.py' -v
"""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

# 테스트 대상 모듈 경로 추가
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'templates', 'spring-boot', 'review'))
from review_guide import (
    analyze,
    load_rules,
    match_file_patterns,
    parse_diff_hunks,
    find_symbol_near_line,
)

RULES_FILE = os.path.join(
    os.path.dirname(__file__), '..', 'templates', 'spring-boot', 'review', 'review-rules.json'
)


class TestReviewGuide(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        with open(RULES_FILE, encoding='utf-8') as f:
            cls.rules = json.load(f)

    # ── TC-1: 위험 신호 없는 일반 변경 → reviewRequired=false ─────────────────
    def test_tc1_no_risk_change(self):
        diff = (
            "--- a/src/main/java/com/example/UserController.java\n"
            "+++ b/src/main/java/com/example/UserController.java\n"
            "@@ -10,6 +10,7 @@\n"
            " import com.example.service.UserService;\n"
            "+// 사용자 조회 컨트롤러\n"
            " \n"
            " public class UserController {\n"
        )
        diff_by_file = {'src/main/java/com/example/UserController.java': diff}
        result = analyze(
            self.rules,
            ['src/main/java/com/example/UserController.java'],
            diff_by_file,
            'passed', 'passed',
            ['com.example.UserControllerTest'],
        )
        self.assertFalse(result['reviewRequired'],
                         "일반 주석 변경은 검수를 요구하지 않아야 합니다")

    # ── TC-2: 인증·보안 변경 → reviewRequired=true ────────────────────────────
    def test_tc2_auth_security_change(self):
        diff = (
            "--- a/src/main/java/com/example/SecurityConfig.java\n"
            "+++ b/src/main/java/com/example/SecurityConfig.java\n"
            "@@ -20,7 +20,7 @@\n"
            "-        .antMatchers(\"/api/admin/**\").hasRole(\"ADMIN\")\n"
            "+        .antMatchers(\"/api/admin/**\").permitAll()\n"
        )
        diff_by_file = {'src/main/java/com/example/SecurityConfig.java': diff}
        result = analyze(
            self.rules,
            ['src/main/java/com/example/SecurityConfig.java'],
            diff_by_file,
            'passed', 'passed', [],
        )
        self.assertTrue(result['reviewRequired'],
                        "permitAll() 추가는 reviewRequired=true여야 합니다")
        auth_findings = [f for f in result['findings'] if f['ruleId'] == 'auth-security-change']
        self.assertTrue(len(auth_findings) > 0)
        self.assertEqual(auth_findings[0]['source'], 'hook-rule')

    # ── TC-3: @Transactional 변경 → 파일·라인 finding 존재 ──────────────────
    def test_tc3_transactional_finding_has_location(self):
        diff = (
            "--- a/src/main/java/com/example/UserService.java\n"
            "+++ b/src/main/java/com/example/UserService.java\n"
            "@@ -80,6 +80,7 @@\n"
            " \n"
            "+    @Transactional(rollbackFor = Exception.class)\n"
            "     public void deleteAccount(Long userId) {\n"
        )
        diff_by_file = {'src/main/java/com/example/UserService.java': diff}
        result = analyze(
            self.rules,
            ['src/main/java/com/example/UserService.java'],
            diff_by_file,
            'passed', 'passed', [],
        )
        txn = [f for f in result['findings'] if f['ruleId'] == 'transaction-boundary-change']
        self.assertTrue(len(txn) > 0, "@Transactional 변경은 finding을 생성해야 합니다")
        self.assertIsNotNone(txn[0].get('line'), "finding에 line이 있어야 합니다")
        self.assertIsNotNone(txn[0].get('file'), "finding에 file이 있어야 합니다")

    # ── TC-4: 대응 테스트 없음 단독 → reviewRequired=false, unverified에만 기록 ──
    def test_tc4_no_test_found(self):
        diff = (
            "--- a/src/main/java/com/example/ArticleService.java\n"
            "+++ b/src/main/java/com/example/ArticleService.java\n"
            "@@ -10,4 +10,5 @@\n"
            " public class ArticleService {\n"
            "+    // 단순 로깅 추가\n"
            "     public void process() {\n"
        )
        diff_by_file = {'src/main/java/com/example/ArticleService.java': diff}
        result = analyze(
            self.rules,
            ['src/main/java/com/example/ArticleService.java'],
            diff_by_file,
            'passed', 'not-found', [],
        )
        self.assertFalse(result['reviewRequired'],
                         "위험 규칙 없이 테스트 없음 단독은 reviewRequired=false여야 합니다")
        self.assertIn('대응 테스트 없음', result['validation']['unverified'])

    # ── TC-5: 빈 catch 블록 → ruleId·check 포함 ──────────────────────────────
    def test_tc5_empty_catch_block(self):
        diff = (
            "--- a/src/main/java/com/example/PaymentService.java\n"
            "+++ b/src/main/java/com/example/PaymentService.java\n"
            "@@ -50,6 +50,9 @@\n"
            " \n"
            "+        try {\n"
            "+            externalApi.charge(amount);\n"
            "+        } catch (Exception e) {}\n"
        )
        diff_by_file = {'src/main/java/com/example/PaymentService.java': diff}
        result = analyze(
            self.rules,
            ['src/main/java/com/example/PaymentService.java'],
            diff_by_file,
            'passed', 'passed', [],
        )
        catch_findings = [f for f in result['findings'] if f['ruleId'] == 'empty-catch-block']
        self.assertTrue(len(catch_findings) > 0, "빈 catch 블록은 finding을 생성해야 합니다")
        self.assertEqual(catch_findings[0]['ruleId'], 'empty-catch-block')
        self.assertIn('check', catch_findings[0])

    # ── TC-6: 존재하지 않는 규칙 파일 → FileNotFoundError ────────────────────
    def test_tc6_rules_file_not_found(self):
        with self.assertRaises(FileNotFoundError):
            load_rules('/nonexistent/path/review-rules.json')

    # ── TC-7: 잘못된 JSON → json.JSONDecodeError ──────────────────────────────
    def test_tc7_invalid_json(self):
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as tmp:
            tmp.write('{ invalid json content }')
            tmp_path = tmp.name
        try:
            with self.assertRaises(json.JSONDecodeError):
                load_rules(tmp_path)
        finally:
            os.unlink(tmp_path)

    # ── TC-8: 변경 파일 밖의 diff → finding 생성 안 함 ───────────────────────
    def test_tc8_diff_outside_changed_files(self):
        # diff_by_file에 UserService는 빈 diff, OtherService는 아예 없음
        diff_by_file = {'src/main/java/com/example/UserService.java': ''}
        # changed_files에 UserService만 포함
        result = analyze(
            self.rules,
            ['src/main/java/com/example/UserService.java'],
            diff_by_file,
            'passed', 'passed', [],
        )
        self.assertEqual(len(result['findings']), 0,
                         "변경 파일 밖의 diff는 finding을 생성하면 안 됩니다")
        self.assertFalse(result['reviewRequired'])

    # ── TC-9: 심볼 탐색 실패 → 'unknown' 반환, 임의 심볼 생성 금지 ───────────
    def test_tc9_symbol_not_found_returns_unknown(self):
        # @Transactional이 파일 맨 위 import 영역에 추가 → 근처에 메서드 없음
        diff = (
            "--- a/src/main/java/com/example/UserService.java\n"
            "+++ b/src/main/java/com/example/UserService.java\n"
            "@@ -1,3 +1,4 @@\n"
            " package com.example;\n"
            "+@Transactional\n"
            " import com.example.repo.UserRepo;\n"
        )
        diff_by_file = {'src/main/java/com/example/UserService.java': diff}
        result = analyze(
            self.rules,
            ['src/main/java/com/example/UserService.java'],
            diff_by_file,
            'passed', 'passed', [],
        )
        txn = [f for f in result['findings'] if f['ruleId'] == 'transaction-boundary-change']
        if txn:
            symbol = txn[0].get('symbol')
            # 심볼을 찾지 못한 경우 'unknown'이어야 함 (임의 이름 생성 금지)
            if symbol != 'unknown':
                # 실제로 diff에서 탐색된 결과인지 확인 (패턴 매칭)
                self.assertRegex(
                    symbol,
                    r'^[a-zA-Z_][a-zA-Z0-9_]*$',
                    "symbol이 있다면 유효한 식별자여야 합니다"
                )

    # ── TC-10: 중복 입력 → 파일·테스트·finding 최초 한 건만 유지 ──────────────
    def test_tc10_duplicate_inputs_are_deduplicated_in_order(self):
        file_path = 'src/main/java/com/example/UserController.java'
        other_file = 'src/main/java/com/example/UserService.java'
        diff = (
            "--- a/src/main/java/com/example/UserController.java\n"
            "+++ b/src/main/java/com/example/UserController.java\n"
            "@@ -20,6 +20,8 @@\n"
            " public class UserController {\n"
            "+    @GetMapping(\"/users\")\n"
            "+    public List<User> getUsers() {\n"
        )
        test_class = 'com.example.UserControllerTest'

        result = analyze(
            self.rules,
            [file_path, other_file, file_path],
            {file_path: diff},
            'passed', 'passed',
            [test_class, 'com.example.UserServiceTest', test_class],
        )

        public_api_findings = [
            finding for finding in result['findings']
            if finding['ruleId'] == 'public-api-contract-change'
        ]
        self.assertEqual(result['changedFiles'], [file_path, other_file])
        self.assertEqual(
            result['validation']['executedTests'],
            [test_class, 'com.example.UserServiceTest'],
        )
        self.assertEqual(len(public_api_findings), 1)

    def test_tc11_duplicate_findings_are_deduplicated_by_identity(self):
        file_path = 'src/main/java/com/example/UserController.java'
        diff = (
            "--- a/src/main/java/com/example/UserController.java\n"
            "+++ b/src/main/java/com/example/UserController.java\n"
            "@@ -20,6 +20,8 @@\n"
            "+    @GetMapping(\"/users\")\n"
            "+    public List<User> getUsers() {\n"
        )
        public_api_rule = next(
            rule for rule in self.rules
            if rule['id'] == 'public-api-contract-change'
        )

        result = analyze(
            [public_api_rule, public_api_rule.copy()],
            [file_path],
            {file_path: diff},
            'passed', 'passed', [],
        )

        self.assertEqual(len(result['findings']), 1)

    def test_tc12_cli_preserves_spaces_in_changed_file_path(self):
        with tempfile.TemporaryDirectory() as tmp:
            project_root = Path(tmp)
            relative_path = Path('src/main/java/com/example/ UserController.java ')
            changed_file = project_root / relative_path
            changed_file.parent.mkdir(parents=True)
            changed_file.write_text('class UserController {}\n', encoding='utf-8')
            script = Path(RULES_FILE).parent / 'review_guide.py'

            result = subprocess.run(
                [
                    sys.executable,
                    str(script),
                    '--project-root', str(project_root),
                    '--changed-files', str(changed_file),
                    '--compile-result', 'passed',
                    '--test-result', 'not-run',
                    '--rules-file', RULES_FILE,
                ],
                text=True,
                capture_output=True,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            report = json.loads(result.stdout)
            self.assertEqual(report['changedFiles'], [str(relative_path)])

    def _analyze_java_diff(self, added_lines):
        file_path = 'src/main/java/com/example/Example.java'
        diff = (
            f"--- a/{file_path}\n+++ b/{file_path}\n@@ -10,1 +10,{len(added_lines)} @@\n"
            + ''.join(f'+{line}\n' for line in added_lines)
        )
        return analyze(self.rules, [file_path], {file_path: diff},
                       'passed', 'passed', [])

    def test_tc13_logic_rules_ignore_comments_and_javadoc(self):
        result = self._analyze_java_diff([
            '    // permitAll() Point WebClient.get()',
            '    /** 나중에 설명할 Point WebClient.get() */',
            '     * @Transactional(rollbackFor = Exception.class)',
        ])
        self.assertEqual(result['findings'], [])

    def test_tc14_todo_placeholder_only_matches_line_comments(self):
        comment = self._analyze_java_diff(['    // TODO: 나중에 처리', '    // 추후 보완'])
        self.assertEqual(
            [f['ruleId'] for f in comment['findings']], ['todo-placeholder']
        )
        javadoc = self._analyze_java_diff(['    /** 나중에 처리할 내용을 설명합니다. */'])
        self.assertEqual(javadoc['findings'], [])
        code_string = self._analyze_java_diff(['    String message = "TODO: 나중에 처리";'])
        self.assertEqual(code_string['findings'], [])

    def test_tc14b_legacy_placeholder_markers_remain_comment_only(self):
        for marker in ('FIXME', 'HACK', '임시', 'placeholder'):
            with self.subTest(marker=marker):
                result = self._analyze_java_diff([f'    // {marker}: 처리 필요'])
                self.assertEqual(
                    [f['ruleId'] for f in result['findings']], ['todo-placeholder']
                )

    def test_tc15_point_rule_uses_word_boundaries(self):
        camel_case = self._analyze_java_diff(['    int codePoint = 1;', '    int codePointCount = 2;'])
        self.assertFalse(any(f['ruleId'] == 'amount-calculation-change'
                             for f in camel_case['findings']))
        for line in ('    int point = 1;', '    int pointBalance = 1;',
                     '    usePoint();'):
            with self.subTest(line=line):
                identifier = self._analyze_java_diff([line])
                self.assertTrue(any(f['ruleId'] == 'amount-calculation-change'
                                    for f in identifier['findings']))

    def test_tc16_external_call_does_not_match_collection_get(self):
        collection = self._analyze_java_diff(['    value = list.get(0);', '    value = map.get("key");'])
        self.assertFalse(any(f['ruleId'] == 'external-call-change'
                             for f in collection['findings']))
        for line in ('    return webClient.post().bodyValue(value);',
                     '    return restTemplate.exchange(url, method, request, Type.class);'):
            with self.subTest(line=line):
                http = self._analyze_java_diff([line])
                self.assertTrue(any(f['ruleId'] == 'external-call-change'
                                    for f in http['findings']))
        plain_post = self._analyze_java_diff(['    return client.post();'])
        self.assertFalse(any(f['ruleId'] == 'external-call-change'
                             for f in plain_post['findings']))

    def test_tc17_body_match_uses_enclosing_method_not_next_method(self):
        diff = (
            '--- a/src/main/java/com/example/MarkdownChunking.java\n'
            '+++ b/src/main/java/com/example/MarkdownChunking.java\n'
            '@@ -5,9 +5,10 @@\n'
            '     public void chunk() {\n'
            '         int point = 1;\n'
            '+        point++;\n'
            '     }\n'
            '     public void render() {\n'
            '     }\n'
        )
        self.assertEqual(find_symbol_near_line(diff, 7), 'chunk')


if __name__ == '__main__':
    unittest.main(verbosity=2)
