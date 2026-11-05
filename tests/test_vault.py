"""Offline integration tests: real local Git, PowerShell 5.1, no GitHub mutations."""
import json
import shutil
import subprocess
import unittest
from pathlib import Path
from uuid import uuid4

SOURCE = Path(__file__).resolve().parents[1]


class VaultTests(unittest.TestCase):
    def setUp(self):
        self.work = SOURCE / 'work' / ('test-' + uuid4().hex)
        self.repo = self.work / 'vault'
        self.repo.mkdir(parents=True)
        for folder in ('tools', 'docs', 'skills'):
            shutil.copytree(SOURCE / folder, self.repo / folder)
        (self.repo / 'notes' / 'bugs').mkdir(parents=True)
        (self.repo / '.gitignore').write_text('work/\n', encoding='utf-8')
        self.git('init', '-b', 'main')
        self.git('config', 'user.name', 'Offline Test')
        self.git('config', 'user.email', 'test@example.invalid')
        self.note_id = '2026-11-05-collision-test'
        self.note = self.repo / 'notes' / 'bugs' / (self.note_id + '.md')
        self.note.write_text(self.content(status='formalized'), encoding='utf-8')
        self.git('add', '.')
        self.git('commit', '-m', 'fixture')
        self.remote = self.work / 'origin.git'
        subprocess.run(['git', 'init', '--bare', str(self.remote)], check=True, capture_output=True)
        self.git('remote', 'add', 'origin', str(self.remote))
        self.git('push', '-u', 'origin', 'main')
        self.git('symbolic-ref', 'refs/remotes/origin/HEAD', 'refs/remotes/origin/main')

    def git(self, *args):
        return subprocess.run(['git', '-C', str(self.repo), *args], check=True, capture_output=True, text=True, encoding='utf-8').stdout.strip()

    def run_vault(self, *args, ok=True):
        result = subprocess.run(['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(self.repo / 'tools/vault.ps1'), *args], capture_output=True, text=True, encoding='utf-8', errors='replace')
        self.assertEqual(result.returncode, 0 if ok else 1, result.stdout + result.stderr)
        return result.stdout

    def content(self, note_id=None, status='draft', version='2022.3', date="'2026-11-05'"):
        return f'''---
id: {note_id or self.note_id}
title: Real note title
category: bugs
status: {status}
tags: [collision, ECONNREFUSED]
created: {date}
updated: {date}
unity_version: "{version}"
platform: Windows
verification: reproduced
diagnosis: unknown
resolution: workaround
source:
  - title: Reference title must not overwrite note title
    url: https://example.invalid/docs
---
## Summary
ECONNREFUSED when connecting to the local bridge.
## Symptoms
The connection was refused.
## AI Prompt
Check the environment before suggesting a fix.
'''

    def draft(self, note_id='2026-11-05-new-note', **kwargs):
        p = self.work / (note_id + '.md')
        p.write_text(self.content(note_id=note_id, **kwargs), encoding='utf-8')
        return p

    def test_index_metadata_and_search(self):
        self.run_vault('index')
        index = json.loads((self.repo / 'notes/index.json').read_text(encoding='utf-8-sig'))
        row = index['notes'][0]
        self.assertEqual(row['title'], 'Real note title')
        self.assertEqual(row['updated'], '2026-11-05')
        self.assertEqual(row['verification'], 'reproduced')
        self.assertEqual(row['platform'], 'Windows')
        self.assertIsNone(row['render_pipeline'])
        # Search reads the note itself, not an old or manually edited index.
        result = json.loads(self.run_vault('search', '-Query', 'ECONNREFUSED', '-Json'))
        self.assertEqual(result[0]['Id'], self.note_id)
        self.assertIn('unspecified', result[0]['Environment'])
        self.assertEqual(json.loads(self.run_vault('search', '-Query', 'ECONNREFUSED', '-UnityVersion', '6000.3', '-Json')), [])

    def test_search_draft_and_deprecated_visibility(self):
        self.note.write_text(self.content(status='draft'), encoding='utf-8')
        self.assertEqual(json.loads(self.run_vault('search', '-Query', 'ECONNREFUSED', '-Json')), [])
        self.assertEqual(len(json.loads(self.run_vault('search', '-Query', 'ECONNREFUSED', '-IncludeDrafts', '-Json'))), 1)
        self.note.write_text(self.content(status='deprecated'), encoding='utf-8')
        self.assertEqual(json.loads(self.run_vault('search', '-Query', 'ECONNREFUSED', '-IncludeDrafts', '-Json')), [])

    def test_validation_errors_have_nonzero_exit(self):
        good = self.draft()
        self.assertIn('PASS', self.run_vault('validate', '-File', str(good)))
        good.write_text(self.content(note_id=good.stem, date='2026-02-30'), encoding='utf-8')
        self.assertIn('invalid date', self.run_vault('validate', '-File', str(good), ok=False))
        good.write_text(self.content(note_id=good.stem).replace('diagnosis: unknown', 'diagnosis: fabricated'), encoding='utf-8')
        self.assertIn('invalid diagnosis', self.run_vault('validate', '-File', str(good), ok=False))
        good.write_text(self.content(note_id=good.stem).replace('title: Real note title', 'title: A\ntitle: B'), encoding='utf-8')
        self.assertIn('Duplicate', self.run_vault('validate', '-File', str(good), ok=False))
        good.write_text(self.content(note_id=good.stem).replace('platform: Windows', 'platform: "\u5f85\u586b\u5199"'), encoding='utf-8')
        self.assertIn('placeholder', self.run_vault('validate', '-File', str(good), ok=False))

    def test_dry_run_does_not_change_branch_files_or_remote(self):
        draft = self.draft()
        before = self.git('rev-parse', 'HEAD')
        self.run_vault('post', '-File', str(draft), '-DryRun')
        self.assertEqual(self.git('rev-parse', 'HEAD'), before)
        self.assertEqual(self.git('branch', '--show-current'), 'main')
        self.assertFalse((self.repo / 'notes/bugs' / draft.name).exists())

    def test_real_local_post_commit_and_update(self):
        draft = self.draft()
        self.run_vault('post', '-File', str(draft), '-NoPush')
        self.assertEqual(self.git('branch', '--show-current'), 'note/' + draft.stem)
        index = json.loads((self.repo / 'notes/index.json').read_text(encoding='utf-8-sig'))
        self.assertEqual(len(index['notes']), 2)
        self.assertEqual(self.git('status', '--porcelain'), '')
        # -NoPush really leaves the remote unchanged.
        self.assertEqual(self.git('ls-remote', '--heads', 'origin', 'refs/heads/note/' + draft.stem), '')
        # Correct a note that is already on main, preserving its id/creation date.
        revised = self.draft(note_id=self.note_id)
        revised.write_text(revised.read_text().replace('Real note title', 'Corrected title'), encoding='utf-8')
        self.run_vault('post', '-File', str(revised), '-Update', '-NoPush')
        self.assertTrue(self.git('branch', '--show-current').startswith('note/' + self.note_id + '-update-'))
        self.assertIn('Corrected title', self.note.read_text(encoding='utf-8-sig'))
        self.assertEqual(len(json.loads((self.repo / 'notes/index.json').read_text(encoding='utf-8-sig'))['notes']), 1)

    def test_post_refuses_dirty_tree_and_formalized_submission(self):
        draft = self.draft()
        self.note.write_text(self.note.read_text() + '\nLocal work\n', encoding='utf-8')
        self.assertIn('uncommitted', self.run_vault('post', '-File', str(draft), '-NoPush', ok=False))
        self.assertEqual(self.git('branch', '--show-current'), 'main')
        formal = self.draft(status='formalized')
        self.assertIn('draft/review only', self.run_vault('post', '-File', str(formal), '-NoPush', ok=False))

    def test_feedback_dry_run_no_network(self):
        self.git('remote', 'set-url', 'origin', 'https://github.com/example/vault.git')
        text = self.run_vault('feedback', '-NoteId', self.note_id, '-Message', 'Does not work on Unity 6', '-DryRun')
        self.assertIn('Would create', text)
        self.assertIn(self.note_id, text)

    def test_setup_is_local_repeatable_and_installs_correct_paths(self):
        agent = self.work / 'agent-skills'
        codex = self.work / 'codex-skills'
        command = ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(self.repo / 'tools/setup.ps1'), '-Root', str(self.repo), '-UserName', 'Student', '-Email', 'student@example.invalid', '-AgentSkillsRoot', str(agent), '-CodexSkillsRoot', str(codex)]
        before = subprocess.run(['git', 'config', '--global', '--list'], capture_output=True).stdout
        for _ in range(2):
            result = subprocess.run(command, capture_output=True, text=True, encoding='utf-8', errors='replace')
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.git('config', '--local', '--get', 'user.name'), 'Student')
        self.assertEqual(before, subprocess.run(['git', 'config', '--global', '--list'], capture_output=True).stdout)
        for folder in (agent, codex):
            skill = folder / 'posting-vault-notes/SKILL.md'
            self.assertIn(str(self.repo), skill.read_text(encoding='utf-8'))
            self.assertNotIn('$env:USERPROFILE\\Unity-Dev-Notes', skill.read_text(encoding='utf-8'))

    def test_pr_create_reuse_and_failure_contract(self):
        test = self.work / 'pr-contract.ps1'
        test.write_text(r'''
$ErrorActionPreference = 'Stop'
. '__SCRIPT__'
function Get-GitHubContext { return @{ Owner='owner'; FullName='owner/vault' } }
function Get-GitHubHeaders { return @{ Authorization='test-only' } }
function Get-DefaultBranch { return 'main' }
$script:created = 0; $script:existing = $false; $script:failApi = $false
function Invoke-VaultApi {
 param($Path,$Headers,$Method='GET',$Payload)
 if ($script:failApi) { throw 'Simulated API failure' }
 if ($Method -eq 'GET') {
   if ($Path -notmatch 'head=owner%3Anote%2Ftest') { throw 'Head filter not encoded correctly' }
   if ($script:existing) { return @{ html_url='https://github.com/owner/vault/pull/7'; state='open' } }
   return
 }
 if ($Payload.head -ne 'note/test' -or $Payload.base -ne 'main') { throw 'Wrong PR branch payload' }
 $script:created++
 return @{ html_url='https://github.com/owner/vault/pull/7'; state='open' }
}
$pr = Get-OrCreatePullRequest 'unused' 'note/test' 'Title'
if ($script:created -ne 1 -or $pr.html_url -notmatch '/pull/7$') { throw 'PR not created' }
$script:existing = $true
$null = Get-OrCreatePullRequest 'unused' 'note/test' 'Title'
if ($script:created -ne 1) { throw 'Created a duplicate PR' }
function Run-Git { return @{Code=0;Out='remote-branch-hash'} }
$script:failApi = $true
$failed = $false
try { Complete-PullRequest 'unused' 'note/test' 'Title' } catch { $failed = $true }
if (-not $failed) { throw 'API failure was hidden' }
Write-Output 'PR_CONTRACT_PASS'
'''.replace('__SCRIPT__', str(self.repo / 'tools/vault.ps1')), encoding='utf-8')
        result = subprocess.run(['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(test)], capture_output=True, text=True, encoding='utf-8', errors='replace')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('PR_CONTRACT_PASS', result.stdout)
        self.assertIn('PR_PENDING', result.stdout)
        self.assertNotIn('PENDING_REVIEW', result.stdout)


if __name__ == '__main__':
    unittest.main(verbosity=2)
