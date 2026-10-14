"""Exercise the real publisher/summary without GitHub writes or git pushes."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BASH = shutil.which('bash')
if os.name == 'nt':
    BASH = str(Path(shutil.which('git')).parents[1] / 'bin' / 'bash.exe')

MOCKS = r'''
git() {
  printf 'git %s\n' "$*" >> "$CALL_LOG"
  case "$*" in
    'rev-parse HEAD') echo proposal-sha ;;
    'rev-parse HEAD:core/Clash.Meta') echo "$PINNED_SHA" ;;
  esac
}
gh() {
  printf 'gh %s\n' "$*" >> "$CALL_LOG"
  case "$1 $2" in
    'pr list') printf '%s\n' "${EXISTING_PR:-}" ;;
    'pr view') echo false ;;
    'pr create') echo https://github.com/owner/repo/pull/42 ;;
  esac
}
source "$SCRIPT_PATH"
'''


class ReportingTests(unittest.TestCase):
    def run_script(self, script, **overrides):
        with tempfile.TemporaryDirectory(prefix='mihomo-report-') as temporary:
            work = Path(temporary)
            (work / 'review.md').write_text('Reviewed compatibility result', encoding='utf-8')
            (work / 'mihomo-core-validation.log').write_text('patch application failed', encoding='utf-8')
            env = os.environ | {
                'BRANCH': 'codex/mihomo-core-v1.19.32',
                'LATEST_TAG': 'v1.19.32', 'LATEST_SHA': 'stable-sha',
                'PINNED_SHA': 'stable-sha', 'GITHUB_REPOSITORY': 'owner/repo',
                'GITHUB_SERVER_URL': 'https://github.com', 'GITHUB_RUN_ID': '123',
                'RUNNER_TEMP': work.as_posix(),
                'GITHUB_OUTPUT': (work / 'output').as_posix(),
                'CALL_LOG': (work / 'calls').as_posix(),
                'SCRIPT_PATH': (ROOT / 'scripts' / script).as_posix(),
                'REVIEW_FILE': (work / 'review.md').as_posix(),
                'VALIDATION_OUTCOME': 'success', 'DEPENDENCIES_OUTCOME': 'success',
                'REVIEW_OUTCOME': 'success', 'REVIEW_CONCLUSION': 'reviewed',
                'SETUP_GO_OUTCOME': 'success', 'JOB_STATUS': 'success',
                'ACTION': 'upgrade_stable', 'PUBLICATION_OUTCOME': 'success',
                'PR_NUMBER': '42', 'EXISTING_PR': '', 'DRY_RUN': 'false',
            } | overrides
            result = subprocess.run([BASH, '-c', MOCKS], env=env, text=True,
                                    encoding='utf-8', capture_output=True)
            def read(name):
                path = work / name
                return path.read_text(encoding='utf-8') if path.exists() else ''
            return result, read('calls'), read('mihomo-update-pr.md'), read('output')

    def test_failed_validation_creates_blocked_draft(self):
        result, calls, body, output = self.run_script(
            'publish_mihomo_update.sh', VALIDATION_OUTCOME='failure',
            REVIEW_OUTCOME='skipped')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('state=failure', calls)
        self.assertIn('context=Mihomo core update validation', calls)
        self.assertIn('--draft --base beta', calls)
        self.assertIn('patch application failed', body)
        self.assertIn('当前禁止合并', body)
        self.assertNotIn('Reviewed compatibility result', body)
        self.assertIn('pr_number=42', output)

    def test_setup_failure_still_publishes_review(self):
        result, calls, body, _ = self.run_script(
            'publish_mihomo_update.sh', SETUP_GO_OUTCOME='failure',
            DEPENDENCIES_OUTCOME='skipped', VALIDATION_OUTCOME='skipped',
            REVIEW_OUTCOME='skipped')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('state=failure', calls)
        self.assertIn('Go 环境准备：failure', body)

    def test_passed_validation_attaches_review_to_exact_commit(self):
        result, calls, body, _ = self.run_script('publish_mihomo_update.sh')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('statuses/proposal-sha', calls)
        self.assertIn('state=success', calls)
        self.assertIn('Reviewed compatibility result', body)
        self.assertIn('--draft --base beta', calls)

    def test_existing_ready_pr_returns_to_draft(self):
        result, calls, _, output = self.run_script(
            'publish_mihomo_update.sh', EXISTING_PR='17',
            VALIDATION_OUTCOME='failure', REVIEW_OUTCOME='skipped')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('pr ready 17 --repo owner/repo --undo', calls)
        self.assertIn('pr edit 17', calls)
        self.assertNotIn('pr create', calls)
        self.assertIn('pr_number=17', output)

    def test_wrong_core_commit_never_pushes_or_opens_pr(self):
        result, calls, _, _ = self.run_script(
            'publish_mihomo_update.sh', PINNED_SHA='wrong-sha')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('git push', calls)
        self.assertNotIn('gh ', calls)

    def test_summary_reports_real_validation_and_publication_outcomes(self):
        result, _, _, _ = self.run_script('mihomo_update_summary.sh',
            VALIDATION_OUTCOME='failure', REVIEW_OUTCOME='skipped', JOB_STATUS='failure')
        self.assertIn('验证：失败或未完成', result.stdout)
        self.assertIn('Draft PR：#42', result.stdout)
        self.assertNotIn('验证：通过', result.stdout)
        result, _, _, _ = self.run_script('mihomo_update_summary.sh',
            PUBLICATION_OUTCOME='failure', PR_NUMBER='')
        self.assertIn('PR 发布失败或未完成', result.stdout)
        self.assertNotIn('Draft PR：#', result.stdout)

    def test_dry_run_and_current_validation_do_not_claim_a_pr(self):
        for overrides in [dict(DRY_RUN='true'), dict(ACTION='validate_current')]:
            result, _, _, _ = self.run_script('mihomo_update_summary.sh',
                VALIDATION_OUTCOME='failure', **overrides)
            self.assertIn('验证：失败或未完成', result.stdout)
            self.assertNotIn('Draft PR', result.stdout)

    def test_workflow_publishes_after_failure_but_not_dry_run_or_cancellation(self):
        workflow = (ROOT / '.github/workflows/mihomo-core-update.yml').read_text(encoding='utf-8')
        publisher = workflow.split('- name: Publish update review\n', 1)[1].split('- name: Summary', 1)[0]
        self.assertIn('!cancelled()', publisher)
        self.assertIn("steps.update.outputs.branch != ''", publisher)
        self.assertIn('inputs.dry_run != true', publisher)
        self.assertIn('steps.validation.outcome', publisher)
        self.assertLess(workflow.index('- name: Update Mihomo submodule'),
                        workflow.index('- name: Setup Go for validation'))


if __name__ == '__main__':
    unittest.main()
