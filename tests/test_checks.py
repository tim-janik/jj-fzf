# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0

from pathlib import Path
import os
import subprocess
import tempfile
import unittest


SCRIPTS = Path (__file__).resolve().parent
GIT_ENV = { key: value for key, value in os.environ.items() if not key.startswith ('GIT_') }
GIT_ENV.update (GIT_CONFIG_GLOBAL = '/dev/null', GIT_CONFIG_NOSYSTEM = '1',
                GIT_AUTHOR_NAME = 'Test', GIT_AUTHOR_EMAIL = 'test@example.invalid',
                GIT_COMMITTER_NAME = 'Test', GIT_COMMITTER_EMAIL = 'test@example.invalid')


class AgentsMdTests (unittest.TestCase):
  def setUp (self):
    temporary = tempfile.TemporaryDirectory()
    self.addCleanup (temporary.cleanup)
    self.root = Path (temporary.name)
    (self.root / 'lib').mkdir()
    (self.root / 'contrib').mkdir()
    (self.root / 'jj-fzf').touch()
    (self.root / 'GNUmakefile').write_text ('include Makefile.mk\n')
    (self.root / 'Makefile.mk').write_text ('all check lint:\n\t@true\nvariable := value\n.PHONY: missing\n')
    (self.root / 'contrib/Makefile.mk').write_text ('child-only:\n')

  def run_check (self, text):
    (self.root / 'AGENTS.md').write_text (text)
    return subprocess.run (['bash', str (SCRIPTS / 'check-agents-md.sh'), 'AGENTS.md'],
                           cwd = self.root, capture_output = True, text = True)

  def test_valid_references_without_git (self):
    result = self.run_check ('`./jj-fzf` `./Makefile.mk` `lib/` `make all` `make check` `make lint`\n'
                             '`KEY` `jjfzf_run` `Evidence:`\n')
    self.assertEqual (result.returncode, 0, result.stderr)

  def test_stale_references_are_reported_once (self):
    result = self.run_check ('`lib/missing.sh` `make missing` `lib/missing.sh`\n')
    self.assertEqual (result.returncode, 1)
    self.assertEqual (sorted (result.stderr.splitlines()), [
      'AGENTS.md: missing make target: missing',
      'AGENTS.md: missing path: lib/missing.sh',
    ])

  def test_make_target_must_be_a_literal_root_rule (self):
    for target in ['check.extra', 'variable', 'child-only']:
      with self.subTest (target = target):
        result = self.run_check (f'`make {target}`\n')
        self.assertEqual (result.returncode, 1)
        self.assertIn (f'missing make target: {target}', result.stderr)

  def test_no_references (self):
    self.assertEqual (self.run_check ('# Plain text\n').returncode, 0)

  def test_missing_document (self):
    result = subprocess.run (['bash', str (SCRIPTS / 'check-agents-md.sh'), 'missing.md'],
                             cwd = self.root, capture_output = True, text = True)
    self.assertNotEqual (result.returncode, 0)


class RemovalsTests (unittest.TestCase):
  source_files = ['jj-fzf', 'GNUmakefile', 'Makefile.mk', 'lib/helper.sh', 'lib/helper.py',
                  'lib/helper.awk', 'contrib/helper.el', '.github/workflows/ci.yml']
  test_files = ['tests/test_helper.py', 'contrib/test-helper.sh', '.github/workflows/test_notice.py',
                '.github/workflows/release-test.sh']
  lines = ''.join (f'line{i}\n' for i in range (12))

  def setUp (self):
    temporary = tempfile.TemporaryDirectory()
    self.addCleanup (temporary.cleanup)
    self.root = Path (temporary.name)
    for name in self.source_files + self.test_files:
      path = self.root / name
      path.parent.mkdir (parents = True, exist_ok = True)
      path.write_text (self.lines)
    self.git ('init', '-q', '-b', 'trunk')
    self.commit ('jj-fzf: baseline')
    self.base = self.git ('rev-parse', 'HEAD')
    self.git ('switch', '-qc', 'work')

  def git (self, *args):
    return subprocess.check_output (['git', *args], cwd = self.root, env = GIT_ENV,
                                    stderr = subprocess.PIPE, text = True).strip()

  def commit (self, message):
    self.git ('add', '-A')
    self.git ('commit', '-q', '-m', message)

  def run_check (self, *args, cwd = None):
    return subprocess.run (['bash', str (SCRIPTS / 'check-removals.sh'), *args],
                           cwd = cwd or self.root, env = GIT_ENV, capture_output = True, text = True)

  def test_source_file_types_need_evidence (self):
    for name in self.source_files:
      with self.subTest (name = name):
        base = self.git ('rev-parse', 'HEAD')
        (self.root / name).write_text ('')
        self.commit (f'{name}: remove logic')
        result = self.run_check (base, 'HEAD')
        self.assertEqual (result.returncode, 1, result.stderr)
        self.assertIn (f'{name}: remove logic: removes 12 source lines', result.stderr)

  def test_evidence_must_contain_text (self):
    for evidence, expected in [('Evidence:', 1), ('Evidence:   ', 1), ('  Evidence: reason', 1),
                                (f'Evidence: {self.base} added this unused workaround.', 0)]:
      with self.subTest (evidence = evidence):
        base = self.git ('rev-parse', 'HEAD')
        (self.root / 'jj-fzf').write_text ('')
        self.commit (f'jj-fzf: remove logic\n\n{evidence}')
        result = self.run_check (base, 'HEAD')
        self.assertEqual (result.returncode, expected, result.stderr)
        (self.root / 'jj-fzf').write_text (self.lines)
        self.commit ('jj-fzf: restore fixture')

  def test_threshold_is_per_commit (self):
    (self.root / 'jj-fzf').write_text ('line0\nline1\nline2\n')
    self.commit ('jj-fzf: remove nine lines')
    (self.root / 'jj-fzf').write_text ('')
    self.commit ('jj-fzf: remove three lines')
    self.assertEqual (self.run_check().returncode, 0)

  def test_tests_and_generated_files_are_excluded (self):
    generated = self.root / 'lib/helper.g.sh'
    generated.write_text (self.lines)
    self.commit ('lib/helper.g.sh: add generated fixture')
    for name in self.test_files:
      (self.root / name).write_text ('')
    generated.write_text ('')
    self.commit ('tests/: remove fixtures')
    self.assertEqual (self.run_check().returncode, 0)

  def test_pure_rename_is_not_a_removal (self):
    self.git ('mv', 'jj-fzf', 'renamed.sh')
    self.commit ('jj-fzf: rename')
    self.assertEqual (self.run_check().returncode, 0)

  def test_explicit_range_survives_trunk_advancing (self):
    (self.root / 'jj-fzf').write_text ('')
    self.commit ('jj-fzf: remove logic')
    self.git ('branch', '-f', 'trunk')
    self.assertEqual (self.run_check().returncode, 0)
    self.assertEqual (self.run_check (self.base, 'HEAD').returncode, 1)

  def test_remote_trunk_is_used_before_local_trunk (self):
    self.git ('update-ref', 'refs/remotes/origin/trunk', self.base)
    (self.root / 'jj-fzf').write_text ('')
    self.commit ('jj-fzf: remove logic')
    self.git ('branch', '-f', 'trunk')
    self.assertEqual (self.run_check().returncode, 1)

  def test_missing_history_and_invalid_ranges_fail (self):
    self.git ('branch', '-D', 'trunk')
    result = self.run_check()
    self.assertNotEqual (result.returncode, 0)
    self.assertIn ('Missing trunk history', result.stderr)
    self.assertEqual (self.run_check (self.base, 'HEAD').returncode, 0)
    self.assertNotEqual (self.run_check ('missing', 'HEAD').returncode, 0)
    self.assertNotEqual (self.run_check (self.base, 'missing').returncode, 0)

  def test_tarball_skips_history_but_explicit_range_fails (self):
    with tempfile.TemporaryDirectory() as directory:
      result = self.run_check (cwd = directory)
      self.assertEqual (result.returncode, 0)
      self.assertIn ('SKIP', result.stdout)
      self.assertNotEqual (self.run_check (self.base, 'HEAD', cwd = directory).returncode, 0)


if __name__ == '__main__':
  unittest.main()
